import SwiftUI
import CoreGraphics
import Foundation

struct MandelbrotGenerator: NSViewControllerRepresentable {
    let iterdepth: Int
    @Binding var isgen: Bool
    @Binding var progress: Double
    @Binding var cancelrend: Bool
    @EnvironmentObject var coordinator: RendererCoordinator

    func makeNSViewController(context: Context) -> MandelbrotCPUController {
        let controller = MandelbrotCPUController()
        controller.iter = iterdepth
        controller.isgenbind = $isgen
        controller.progbind = $progress
        controller.candrendbind = $cancelrend
        coordinator.cpucont = controller
        return controller
    }

    func updateNSViewController(_ nsViewController: MandelbrotCPUController, context: Context) {
        nsViewController.iter = iterdepth
        nsViewController.isgenbind = $isgen
        nsViewController.progbind = $progress
        nsViewController.candrendbind = $cancelrend
        if isgen && !nsViewController.hasRendered && !cancelrend {
            nsViewController.renderMandelbrot()
        }
    }
}

class MandelbrotCPUController: NSViewController {
    
    func getRenderedImage() -> NSImage? {
        return imgview?.image
    }
    
    var iter: Int
    var isgenbind: Binding<Bool>?
    var progbind: Binding<Double>?
    var candrendbind: Binding<Bool>?
    private var centerX: Double = -0.5
    private var centerY: Double = 0.0
    private var scale: Double = 2.0
    private var imgview: NSImageView?
    private var zoomlvl: Double = 1.0
    private var offsetX: Double = 0.0
    private var offsetY: Double = 0.0
    private var dragstart: NSPoint?
    var hasRendered: Bool = false

    init() {
        self.iter = 20
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        hasRendered = false
        candrendbind?.wrappedValue = true
    }

    func renderMandelbrot() {
        guard !hasRendered else {
            return
        }
        isgenbind?.wrappedValue = true
        progbind?.wrappedValue = 0.0
        candrendbind?.wrappedValue = false
        hasRendered = true

        DispatchQueue.global(qos: .userInitiated).async {
            let baseRes = 2048
            let res = max(4096, baseRes + self.iter * 100)
            let width = res
            let height = res

            guard width > 0, height > 0 else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.progbind?.wrappedValue = 0.0
                    self.hasRendered = false
                }
                return
            }

            let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.progbind?.wrappedValue = 0.0
                    self.hasRendered = false
                }
                return
            }

            let pixels = context.data?.bindMemory(to: UInt32.self, capacity: width * height)
            guard pixels != nil else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.progbind?.wrappedValue = 0.0
                    self.hasRendered = false
                }
                return
            }

            let maxconcurrentRows = max(1, ProcessInfo.processInfo.activeProcessorCount / 2)
            let rowGroups = (height + maxconcurrentRows - 1) / maxconcurrentRows

            for group in 0..<rowGroups {
                guard self.candrendbind?.wrappedValue == false else {
                    DispatchQueue.main.async {
                        self.isgenbind?.wrappedValue = false
                        self.progbind?.wrappedValue = 0.0
                        self.hasRendered = false
                    }
                    return
                }

                let startRow = group * maxconcurrentRows
                let endRow = min(startRow + maxconcurrentRows, height)
                DispatchQueue.concurrentPerform(iterations: endRow - startRow) { index in
                    let row = startRow + index
                    for col in 0..<width {
                        guard self.candrendbind?.wrappedValue == false else { return }

                        let x0 = self.centerX + (Double(col) / Double(width) - 0.5) * self.scale * 2.0
                        let y0 = self.centerY + (Double(row) / Double(height) - 0.5) * self.scale * 2.0
                        var x: Double = 0.0
                        var y: Double = 0.0
                        var iteration = 0

                        while iteration < self.iter && x * x + y * y <= 4.0 {
                            let xtemp = x * x - y * y + x0
                            y = 2.0 * x * y + y0
                            x = xtemp
                            iteration += 1
                        }

                        let color: UInt32
                        if iteration < self.iter {
                            let smoothIter = Double(iteration) + 1.0 - log2(max(1e-10, log2(x * x + y * y)))
                            let hue = (smoothIter / Double(self.iter) * 360.0).truncatingRemainder(dividingBy: 360.0)
                            let sat = 0.9
                            let value = min(0.7 + smoothIter / Double(self.iter) * 0.3, 1.0)
                            let rgb = self.hsvToRGB(hue: hue, saturation: sat, value: value)
                            let alpha = UInt32(255) << 24
                            let red = UInt32(rgb.r * 255) << 16
                            let green = UInt32(rgb.g * 255) << 8
                            let blue = UInt32(rgb.b * 255) << 0
                            color = alpha | red | green | blue
                        } else {
                            color = UInt32(255) << 24
                        }
                        pixels![row * width + col] = color
                    }
                }

                DispatchQueue.main.async {
                    guard self.candrendbind?.wrappedValue == false else { return }
                    let progressValue = Double(endRow) / Double(height)
                    self.progbind?.wrappedValue = progressValue
                }
            }

            guard self.candrendbind?.wrappedValue == false else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.progbind?.wrappedValue = 0.0
                    self.hasRendered = false
                }
                return
            }

            DispatchQueue.main.async {
                self.progbind?.wrappedValue = 1.0
            }

            guard let cgImage = context.makeImage() else {
                DispatchQueue.main.async {
                    self.isgenbind?.wrappedValue = false
                    self.progbind?.wrappedValue = 0.0
                    self.hasRendered = false
                }
                return
            }

            DispatchQueue.main.async {
                guard self.candrendbind?.wrappedValue == false else {
                    self.isgenbind?.wrappedValue = false
                    self.progbind?.wrappedValue = 0.0
                    self.hasRendered = false
                    return
                }
                self.view.subviews.removeAll()
                let imgview = NSImageView(frame: self.view.bounds)
                imgview.image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
                self.view.subviews = [imgview]
                self.imgview = imgview
                self.isgenbind?.wrappedValue = false
                self.updatetransform()
            }
        }
    }

    private func updatetransform() {
        guard let imgview = imgview, let image = imgview.image else { return }
        let imgsize = image.size
        let viewsize = view.bounds.size

        let imgwidth = imgsize.width * zoomlvl
        let imgheight = imgsize.height * zoomlvl

        let x = (viewsize.width - imgwidth) / 2.0 + offsetX
        let y = (viewsize.height - imgheight) / 2.0 + offsetY

        imgview.frame = NSRect(x: x, y: y, width: imgwidth, height: imgheight)
    }

    private func hsvToRGB(hue: Double, saturation: Double, value: Double) -> (r: Double, g: Double, b: Double) {
        let c = value * saturation
        let h = hue / 60.0
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = value - c
        var rgb: (Double, Double, Double)
        switch h {
        case 0..<1: rgb = (c, x, 0.0)
        case 1..<2: rgb = (x, c, 0.0)
        case 2..<3: rgb = (0.0, c, x)
        case 3..<4: rgb = (0.0, x, c)
        case 4..<5: rgb = (x, 0.0, c)
        default: rgb = (c, 0.0, x)
        }
        return (r: rgb.0 + m, g: rgb.1 + m, b: rgb.2 + m)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let isgen = isgenbind?.wrappedValue, !isgen else { return }

        let zoomFactor: Double = 1.5

        if event.deltaY > 0 {
            zoomlvl *= zoomFactor
        } else if event.deltaY < 0 {
            zoomlvl /= zoomFactor
        }

        updatetransform()
    }

    override func mouseDown(with event: NSEvent) {
        guard let isgen = isgenbind?.wrappedValue, !isgen else { return }
        dragstart = view.convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let isgen = isgenbind?.wrappedValue, !isgen, let start = dragstart else { return }
        let current = view.convert(event.locationInWindow, from: nil)
        offsetX += (current.x - start.x)
        offsetY += (current.y - start.y)
        dragstart = current
        updatetransform()
    }

    override func mouseUp(with event: NSEvent) {
        dragstart = nil
    }
}
