import SwiftUI
import CoreGraphics
import Metal
import MetalKit

struct MandelbrotMetal: NSViewControllerRepresentable {
    let iterdepth: Int
    @Binding var isgen: Bool
    @Binding var progress: Double
    @Binding var cancelrend: Bool
    @EnvironmentObject var coordinator: RendererCoordinator

    func makeNSViewController(context: Context) -> MandelbrotGPUController {
        let controller = MandelbrotGPUController()
        controller.iterdepth = iterdepth
        controller.isgenbind = $isgen
        controller.probind = $progress
        controller.cancelrendbind = $cancelrend
        coordinator.gpucont = controller
        return controller
    }

    func updateNSViewController(_ nsViewController: MandelbrotGPUController, context: Context) {
        nsViewController.iterdepth = iterdepth
        nsViewController.isgenbind = $isgen
        nsViewController.probind = $progress
        nsViewController.cancelrendbind = $cancelrend
        if isgen && !nsViewController.hasrendquestionmark && !cancelrend {
            nsViewController.renderMandelbrot()
        }
    }
}

class MandelbrotGPUController: NSViewController {
    
    func getRenderedImage() -> NSImage? {
        return imgview?.image
    }
    
    var iterdepth: Int
    var isgenbind: Binding<Bool>?
    var probind: Binding<Double>?
    var cancelrendbind: Binding<Bool>?
    private var centerX: Double = -0.5
    private var centerY: Double = 0.0
    private var scale: Double = 2.0
    private var imgview: NSImageView?
    private var zoomlvl: Double = 1.0
    private var offsetX: Double = 0.0
    private var offsetY: Double = 0.0
    private var dragStart: NSPoint?
    var hasrendquestionmark: Bool = false
    
    private var metaldevice: MTLDevice?
    private var metalcommandq: MTLCommandQueue?
    private var mps: MTLComputePipelineState?
    private var mtexture: MTLTexture?

    init() {
        self.iterdepth = 20
        super.init(nibName: nil, bundle: nil)
        setupMetal()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        metaldevice = device
        metalcommandq = device.makeCommandQueue()
        
        guard let deflib = device.makeDefaultLibrary(),
              let kernelFunction = deflib.makeFunction(name: "mandelbrotShader") else {
            return
        }
        
        do {
            mps = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            return
        }
    }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 570))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        view.subviews.removeAll()
        imgview = nil
        hasrendquestionmark = false
        cancelrendbind?.wrappedValue = true
    }

    func renderMandelbrot() {
        guard !hasrendquestionmark else {
            return
        }
        guard let device = metaldevice,
              let commandq = metalcommandq,
              let ps = mps else {
            isgenbind?.wrappedValue = false
            hasrendquestionmark = false
            return
        }

        isgenbind?.wrappedValue = true
        probind?.wrappedValue = 0.0
        cancelrendbind?.wrappedValue = false
        hasrendquestionmark = true

        DispatchQueue.global(qos: .userInitiated).async {
            let baseRes = 2048
            let res = max(4096, baseRes + self.iterdepth * 100)
            let width = res
            let height = res

            guard width > 0, height > 0 else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.probind?.wrappedValue = 0.0
                    self.hasrendquestionmark = false
                }
                return
            }

            let texturedesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            texturedesc.usage = [.shaderWrite, .shaderRead]
            
            guard let texture = device.makeTexture(descriptor: texturedesc) else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.probind?.wrappedValue = 0.0
                    self.hasrendquestionmark = false
                }
                return
            }
            self.mtexture = texture

            struct MandelbrotParams {
                var centerX: Float
                var centerY: Float
                var scale: Float
                var iterdepth: Int32
                var width: Int32
                var height: Int32
            }
            
            var params = MandelbrotParams(
                centerX: Float(self.centerX),
                centerY: Float(self.centerY),
                scale: Float(self.scale),
                iterdepth: Int32(self.iterdepth),
                width: Int32(width),
                height: Int32(height)
            )

            guard let buffee = commandq.makeCommandBuffer(),
                  let encodee = buffee.makeComputeCommandEncoder() else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.probind?.wrappedValue = 0.0
                    self.hasrendquestionmark = false
                }
                return
            }

            encodee.setComputePipelineState(ps)
            encodee.setTexture(texture, index: 0)
            encodee.setBytes(&params, length: MemoryLayout<MandelbrotParams>.size, index: 0)

            let tgsize = MTLSize(width: 16, height: 16, depth: 1)
            let tgcount = MTLSize(
                width: (width + tgsize.width - 1) / tgsize.width,
                height: (height + tgsize.height - 1) / tgsize.height,
                depth: 1
            )
            
            encodee.dispatchThreadgroups(tgcount, threadsPerThreadgroup: tgsize)
            encodee.endEncoding()

            DispatchQueue.main.async {
                self.probind?.wrappedValue = 0.5
            }

            buffee.addCompletedHandler { _ in
                guard self.cancelrendbind?.wrappedValue == false else {
                    DispatchQueue.main.async {
                        self.isgenbind?.wrappedValue = false
                        self.probind?.wrappedValue = 0.0
                        self.hasrendquestionmark = false
                    }
                    return
                }

                let region = MTLRegionMake2D(0, 0, width, height)
                var pixels = [UInt8](repeating: 0, count: width * height * 4)
                texture.getBytes(&pixels, bytesPerRow: width * 4, from: region, mipmapLevel: 0)
                
                let bitmapinfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                guard let dataprov = CGDataProvider(data: NSData(bytes: &pixels, length: pixels.count)),
                      let cgImage = CGImage(
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 32,
                        bytesPerRow: width * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: bitmapinfo),
                        provider: dataprov,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent
                      ) else {
                    DispatchQueue.main.async {
                        self.isgenbind?.wrappedValue = false
                        self.probind?.wrappedValue = 0.0
                        self.hasrendquestionmark = false
                    }
                    return
                }

                DispatchQueue.main.async {
                    guard self.cancelrendbind?.wrappedValue == false else {
                        self.isgenbind?.wrappedValue = false
                        self.probind?.wrappedValue = 0.0
                        self.hasrendquestionmark = false
                        return
                    }
                    self.view.subviews.removeAll()
                    let imgview = NSImageView(frame: self.view.bounds)
                    imgview.image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
                    self.view.subviews = [imgview]
                    self.imgview = imgview
                    self.isgenbind?.wrappedValue = false
                    self.probind?.wrappedValue = 1.0
                    self.updateImageViewTransform()
                }
            }
            
            buffee.commit()
        }
    }

    private func updateImageViewTransform() {
        guard let imgview = imgview, let img = imgview.image else { return }
        let imgsize = img.size
        let viewSize = view.bounds.size

        let imgwidth = imgsize.width * zoomlvl
        let imgheight = imgsize.height * zoomlvl

        let x = (viewSize.width - imgwidth) / 2.0 + offsetX
        let y = (viewSize.height - imgheight) / 2.0 + offsetY

        imgview.frame = NSRect(x: x, y: y, width: imgwidth, height: imgheight)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let isgen = isgenbind?.wrappedValue, !isgen else { return }

        let zoomFactor: Double = 1.5
        if event.deltaY > 0 {
            zoomlvl *= zoomFactor
        } else if event.deltaY < 0 {
            zoomlvl /= zoomFactor
        }

        updateImageViewTransform()
    }

    override func mouseDown(with event: NSEvent) {
        guard let isgen = isgenbind?.wrappedValue, !isgen else { return }
        dragStart = view.convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let isGenerating = isgenbind?.wrappedValue, !isGenerating, let start = dragStart else { return }
        let current = view.convert(event.locationInWindow, from: nil)
        offsetX += (current.x - start.x)
        offsetY += (current.y - start.y)
        dragStart = current
        updateImageViewTransform()
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }
}
