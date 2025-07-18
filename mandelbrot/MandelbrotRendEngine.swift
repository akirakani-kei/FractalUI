import SwiftUI
import MetalKit
import AppKit

struct MandelbrotRendEngine: NSViewControllerRepresentable {
    let iterdepth: Int
    @Binding var isgen: Bool
    @Binding var prog: Double
    @Binding var cancelrend: Bool
    @EnvironmentObject var coordinator: RendererCoordinator

    func makeNSViewController(context: Context) -> MandelbrotRendEngineController {
        let controller = MandelbrotRendEngineController()
        controller.iterdepth = iterdepth
        controller.isgen = $isgen
        controller.progbind = $prog
        controller.cancelrendbind = $cancelrend
        coordinator.rendcontroller = controller
        return controller
    }

    func updateNSViewController(_ nsViewController: MandelbrotRendEngineController, context: Context) {
        nsViewController.iterdepth = iterdepth
        nsViewController.isgen = $isgen
        nsViewController.progbind = $prog
        nsViewController.cancelrendbind = $cancelrend
        if isgen && !nsViewController.hasrend && !cancelrend {
            nsViewController.startRendering()
        }
    }
}

class MandelbrotRendEngineController: NSViewController, MTKViewDelegate {
    var iterdepth: Int = 20
    var isgen: Binding<Bool>?
    var progbind: Binding<Double>?
    var cancelrendbind: Binding<Bool>?
    var hasrend: Bool = false
    private var paused: Bool = false
    private var isinter: Bool = false
    private var debouncetime: Timer?
    private var lastdrawtime: CFAbsoluteTime = 0
    private let lowresscale: Float = 0.25 // fits nicely in the top right

    private var mtlview: MTKView!
    private var device: MTLDevice!
    private var commandq: MTLCommandQueue!
    private var cps: MTLComputePipelineState!
    private var lowrestexture: MTLTexture?
    private var fullrestexture: MTLTexture?
    private var vpsize: vector_uint2 = [0, 0]
    private var center: SIMD2<Double> = [-0.5, 0.0]
    private var scale: Double = 3.0
    private var isdrag: Bool = false
    private var lastmousepoint: NSPoint?

    override func loadView() {
        mtlview = MTKView(frame: .zero)
        mtlview.delegate = self
        self.view = mtlview
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMetal()
        setupInputHandlers()
        mtlview.isPaused = false
        mtlview.enableSetNeedsDisplay = false
        mtlview.framebufferOnly = false
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        mtlview.device = device
        mtlview.colorPixelFormat = .bgra8Unorm
        guard let commandq = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandq = commandq

        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "mandelbrotKernel") else {
            fatalError("Failed to load mandelbrotKernel function from shader")
        }
        do {
            cps = try device.makeComputePipelineState(function: function)
        } catch {
            fatalError("Failed to create compute pipeline state: \(error)")
        }
    }

    private func setuptexture() {
        let fullWidth = Int(mtlview.drawableSize.width)
        let fullHeight = Int(mtlview.drawableSize.height)
        guard fullWidth > 0, fullHeight > 0 else {
            lowrestexture = nil
            fullrestexture = nil
            vpsize = [0, 0]
            paused = true
            return
        }

        let lowWidth = max(1, Int(Float(fullWidth) * lowresscale))
        let lowHeight = max(1, Int(Float(fullHeight) * lowresscale))
        let lowDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: lowWidth,
            height: lowHeight,
            mipmapped: false
        )
        lowDesc.usage = [.shaderRead, .shaderWrite]
        guard let lowTexture = device.makeTexture(descriptor: lowDesc) else {
            lowrestexture = nil
            fullrestexture = nil
            vpsize = [0, 0]
            paused = true
            return
        }

        let fullDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: fullWidth,
            height: fullHeight,
            mipmapped: false
        )
        fullDesc.usage = [.shaderRead, .shaderWrite]
        guard let fullTexture = device.makeTexture(descriptor: fullDesc) else {
            lowrestexture = nil
            fullrestexture = nil
            vpsize = [0, 0]
            paused = true
            return
        }

        lowrestexture = lowTexture
        fullrestexture = fullTexture
        vpsize = [UInt32(lowWidth), UInt32(lowHeight)]
        paused = false
    }

    private func setupInputHandlers() {
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)

        let magnifyGesture = NSMagnificationGestureRecognizer(
            target: self,
            action: #selector(handleMagnifyGesture(_:))
        )
        view.addGestureRecognizer(magnifyGesture)
    }

    func startRendering() {
        if lowrestexture == nil || fullrestexture == nil {
            setuptexture()
        }
        guard lowrestexture != nil, fullrestexture != nil else {
            isgen?.wrappedValue = false
            paused = true
            return
        }
        hasrend = true
        isgen?.wrappedValue = true
        progbind?.wrappedValue = 1.0
        paused = false
        isinter = false
        mtlview.draw()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        paused = true
        debouncetime?.invalidate()
        setuptexture()
        if isgen?.wrappedValue == true && lowrestexture != nil {
            paused = false
            mtlview.draw()
        }
    }

    func draw(in view: MTKView) {
        let ct = CFAbsoluteTimeGetCurrent()
        guard ct - lastdrawtime > 1.0 / 60.0 else { return }
        lastdrawtime = ct

        guard !paused,
              let cbuffer = commandq.makeCommandBuffer(),
              let compencode = cbuffer.makeComputeCommandEncoder(),
              let drawable = view.currentDrawable else {
            return
        }

        let target_texture = isinter ? lowrestexture : fullrestexture
        guard let texture = target_texture else {
            return
        }

        vpsize = [UInt32(texture.width), UInt32(texture.height)]

        compencode.setComputePipelineState(cps)
        compencode.setTexture(texture, index: 0)
        var params = MandelbrotParams(
            center: SIMD2<Float>(Float(center.x), Float(center.y)),
            scale: Float(scale),
            iterations: UInt32(iterdepth),
            viewportSize: vpsize
        )
        compencode.setBytes(&params, length: MemoryLayout<MandelbrotParams>.size, index: 0)

        let tgsize = MTLSize(width: 16, height: 16, depth: 1)
        let tgcount = MTLSize(
            width: (texture.width + tgsize.width - 1) / tgsize.width,
            height: (texture.height + tgsize.height - 1) / tgsize.height,
            depth: 1
        )
        compencode.dispatchThreadgroups(tgcount, threadsPerThreadgroup: tgsize)
        compencode.endEncoding()

        if let blitEncoder = cbuffer.makeBlitCommandEncoder() {
            blitEncoder.copy(
                from: texture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                to: drawable.texture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            blitEncoder.endEncoding()
        }

        cbuffer.present(drawable)
        cbuffer.commit()

        if isgen?.wrappedValue == true && cancelrendbind?.wrappedValue == false && !paused {
            DispatchQueue.main.async { [weak self] in
                self?.mtlview.draw()
            }
        }
    }

    private func schedfullres_render() {
        debouncetime?.invalidate()
        isinter = true
        debouncetime = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.isinter = false
            self.mtlview.draw()
        }
    }

    override func mouseDown(with event: NSEvent) {
        isdrag = true
        lastmousepoint = view.convert(event.locationInWindow, from: nil)
        schedfullres_render()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isdrag, let lastPoint = lastmousepoint else { return }
        let currentPoint = view.convert(event.locationInWindow, from: nil)
        let deltaX = currentPoint.x - lastPoint.x
        let deltaY = currentPoint.y - lastPoint.y
        let deltaC = scale / Double(view.bounds.width)
        center.x -= deltaX * deltaC
        center.y += deltaY * deltaC * (Double(view.bounds.width) / Double(view.bounds.height))
        lastmousepoint = currentPoint
        schedfullres_render()
        mtlview.draw()
    }

    override func mouseUp(with event: NSEvent) {
        isdrag = false
        lastmousepoint = nil
        schedfullres_render()
    }

    override func scrollWheel(with event: NSEvent) {
        let zoomFactor = 1.0 - event.scrollingDeltaY * 0.05
        let mousePoint = view.convert(event.locationInWindow, from: nil)
        let uv = SIMD2<Double>(mousePoint.x / view.bounds.width, 1.0 - mousePoint.y / view.bounds.height)
        let c = center + (uv - 0.5) * scale * SIMD2<Double>(1.0, view.bounds.width / view.bounds.height)
        scale *= zoomFactor
        scale = max(scale, 1e-15)
        center = c - (uv - 0.5) * scale * SIMD2<Double>(1.0, view.bounds.width / view.bounds.height)
        schedfullres_render()
        mtlview.draw()
    }

    @objc func handleMagnifyGesture(_ gesture: NSMagnificationGestureRecognizer) {
        guard gesture.state == .changed || gesture.state == .ended else { return }
        let zoomFactor = 1.0 - Double(gesture.magnification) * 0.5
        let mousePoint = gesture.location(in: view)
        let uv = SIMD2<Double>(mousePoint.x / view.bounds.width, 1.0 - mousePoint.y / view.bounds.height)
        let c = center + (uv - 0.5) * scale * SIMD2<Double>(1.0, view.bounds.width / view.bounds.height)
        scale *= zoomFactor
        scale = max(scale, 1e-15)
        center = c - (uv - 0.5) * scale * SIMD2<Double>(1.0, view.bounds.width / view.bounds.height)
        schedfullres_render()
        mtlview.draw()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        hasrend = false
        cancelrendbind?.wrappedValue = true
        paused = true
        debouncetime?.invalidate()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if isgen?.wrappedValue == true && (lowrestexture == nil || fullrestexture == nil) {
            setuptexture()
            if lowrestexture != nil {
                paused = false
                mtlview.draw()
            }
        }
    }

    func getRenderedImage() -> NSImage? {
        guard let drawable = mtlview.currentDrawable else {
            return nil
        }

        if fullrestexture == nil || fullrestexture!.width != drawable.texture.width || fullrestexture!.height != drawable.texture.height {
            setuptexture()
        }
        guard let texture = fullrestexture,
              let commandBuffer = commandq.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        computeEncoder.setComputePipelineState(cps)
        computeEncoder.setTexture(texture, index: 0)
        var params = MandelbrotParams(
            center: SIMD2<Float>(Float(center.x), Float(center.y)),
            scale: Float(scale),
            iterations: UInt32(iterdepth),
            viewportSize: [UInt32(texture.width), UInt32(texture.height)]
        )
        computeEncoder.setBytes(&params, length: MemoryLayout<MandelbrotParams>.size, index: 0)
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (texture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (texture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()]) else {
            return nil
        }
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: texture.width, height: texture.height))
        return nsImage
    }
}

struct MandelbrotParams {
    var center: SIMD2<Float>
    var scale: Float
    var iterations: UInt32
    var viewportSize: vector_uint2
}
