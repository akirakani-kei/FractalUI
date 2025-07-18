import SwiftUI
import AVFoundation
import Foundation

func isIntelMac() -> Bool {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
    return machine.contains("x86_64")
}

struct bgvideothing: NSViewControllerRepresentable {
    let vidurl: URL
    @Binding var opacity: Double
    @Binding var isPlaying: Bool

    func makeNSViewController(context: Context) -> some NSViewController {
        let controller = vidviewcontroller()
        controller.setupPlayah(with: vidurl)
        return controller
    }

    func updateNSViewController(_ nsviewcont: NSViewControllerType, context: Context) {
        if let controller = nsviewcont as? vidviewcontroller {
            controller.setOpacity(opacity)
            if isPlaying {
                controller.play()
            } else {
                controller.pause()
            }
        }
    }
}

class vidviewcontroller: NSViewController {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    func setupPlayah(with url: URL) {
        player = AVPlayer(url: url)
        player?.isMuted = true

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        view.layer = CALayer()
        view.wantsLayer = true
        view.layer?.addSublayer(playerLayer!)

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: nil
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }

    func setOpacity(_ opacity: Double) {
        playerLayer?.opacity = Float(opacity)
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        playerLayer?.frame = view.bounds
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct fractalopt: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let imageName: String
    let destination: AnyView

    static func == (lhs: fractalopt, rhs: fractalopt) -> Bool {
        return lhs.id == rhs.id
    }
}

class cview_wrapper: ObservableObject {
    @Published var bgopacity: Double = 1.0
    @Published var isPlaying: Bool = true
}


struct ContentView: View {
    let fractals = [
        fractalopt(name: "Mandelbrot Set", imageName: "mandelbrot", destination: AnyView(EmptyView())),
        fractalopt(name: "Sierpinski Triangle", imageName: "sierpinsky", destination: AnyView(EmptyView())),
        fractalopt(name: "Koch Snowflake", imageName: "koch", destination: AnyView(EmptyView())),
        fractalopt(name: "Julia Set", imageName: "julia", destination: AnyView(EmptyView()))
    ]

    @State private var selectedfractal: fractalopt? = nil
    @State private var isMenuVisible = true
    @State private var isTitleVisible = false
    @State private var iconvis = [Bool](repeating: false, count: 4)
    @State private var iconhover = [Bool](repeating: false, count: 4)
    @EnvironmentObject var cview_wrapper: cview_wrapper
    @StateObject private var rendererCoordinator = RendererCoordinator()

    var body: some View {
        ZStack {
            if let videoURL = Bundle.main.url(forResource: "fractal_background", withExtension: "mp4") {
                bgvideothing(
                    vidurl: videoURL,
                    opacity: $cview_wrapper.bgopacity,
                    isPlaying: $cview_wrapper.isPlaying
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            Color.clear
                .background(.ultraThinMaterial.opacity(0.95))
                .ignoresSafeArea()

            if let selectedFractal = selectedfractal {
                Group {
                    switch selectedFractal.name {
                    case "Mandelbrot Set":
                        MandelbrotView(fractalopt: $selectedfractal)
                            .id(selectedFractal.id)
                    case "Sierpinski Triangle":
                        SierpinskiView(selectedFractal: $selectedfractal)
                    case "Koch Snowflake":
                        KochView(selectedFractal: $selectedfractal)
                    case "Julia Set":
                        JuliaView(selectedFractal: $selectedfractal)
                    default:
                        EmptyView()
                    }
                }
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }

            if isMenuVisible && selectedfractal == nil {
                GeometryReader { geometry in
                    VStack {
                        Text("FractalUI")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .opacity(isTitleVisible ? 1 : 0)
                            .padding(.bottom, 60)
                            .frame(maxWidth: .infinity, alignment: .center)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 25) {
                               
                                ForEach(fractals.indices, id: \.self) { index in
                                    let fractal = fractals[index]
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            print("Selecting fractal: \(fractal.name)")
                                            selectedfractal = fractal
                                            isMenuVisible = false
                                        }
                                    }) {
                                        VStack {
                                            Image(fractal.imageName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                        .stroke(Color.black.opacity(0.4), lineWidth: 1)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                        .stroke(Color.white.opacity(iconhover[index] ? 0.4 : 0), lineWidth: 1.5)
                                                        .shadow(color: .white.opacity(iconhover[index] ? 0.15 : 0), radius: 3)
                                                )
                                                .shadow(radius: 8)
                                                .offset(y: iconvis[index] ? (iconhover[index] ? -3 : 0) : 20)
                                                .opacity(iconvis[index] ? 1 : 0)

                                            ZStack {
                                                if iconhover[index] {
                                                    Text(fractal.name)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                                .fill(Color.black.opacity(0.9))
                                                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                                        )
                                                } else {
                                                    Text(fractal.name)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .opacity(0)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                }
                                            }
                                            .padding(.bottom, 4)
                                            .offset(y: 10)
                                        }
                                        .padding(.vertical, 12)
                                        .offset(x: offset_calc(for: index))
                                        .onHover { isHovering in
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                iconhover[index] = isHovering
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                            }
                            .padding(.horizontal)
                            .frame(minWidth: geometry.size.width, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height, alignment: .center)
                }
                .transition(.opacity)
            }
        }
        .onChange(of: selectedfractal) { _, _ in
            print("selectedFractal changed to: \(selectedfractal?.name ?? "nil")")
            if selectedfractal == nil {
                resetmenu()
            }
        }
        .onAppear {
            resetmenu()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(cview_wrapper)
        .environmentObject(rendererCoordinator)
    }

    private func offset_calc(for index: Int) -> CGFloat {
        let offset: CGFloat = 5
        if iconhover[index] {
            return 0
        }
        for i in fractals.indices {
            if iconhover[i] {
                if i < index {
                    return offset
                } else if i > index {
                    return -offset
                }
            }
        }
        return 0
    }

    private func resetmenu() {
        isMenuVisible = true
        isTitleVisible = false
        iconvis = [Bool](repeating: false, count: fractals.count)
        iconhover = [Bool](repeating: false, count: fractals.count)
        cview_wrapper.bgopacity = 1.0
        cview_wrapper.isPlaying = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            menu_fadein()
        }
    }

    private func menu_fadein() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)) {
            isTitleVisible = true
        }

        for index in fractals.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.2)) {
                    iconvis[index] = true
                }
            }
        }
    }
}

struct coolsliderthing: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isDisabled: Bool
    @State private var normalizedPosition: Double

    init(value: Binding<Double>, range: ClosedRange<Double>, step: Double, isDisabled: Bool = false) {
        self._value = value
        self.range = range
        self.step = step
        self.isDisabled = isDisabled
        self._normalizedPosition = State(initialValue: (value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(isDisabled ? 0.4 : 0.7))
                    .frame(height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(isDisabled ? 0.1 : 0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(isDisabled ? 0.4 : 0.8))
                    .frame(width: CGFloat(normalizedPosition) * geometry.size.width, height: 10)

                Circle()
                    .fill(Color.white.opacity(isDisabled ? 0.4 : 1.0))
                    .frame(width: 20, height: 20)
                    .offset(x: CGFloat(normalizedPosition) * (geometry.size.width - 20), y: 0)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .gesture(
                        isDisabled ? nil :
                            DragGesture()
                                .onChanged { drag in
                                    let newNormalized = min(max(drag.location.x / geometry.size.width, 0), 1)
                                    normalizedPosition = newNormalized
                                    let newValue = range.lowerBound + newNormalized * (range.upperBound - range.lowerBound)
                                    let steppedValue = round(newValue / step) * step
                                    value = min(max(steppedValue, range.lowerBound), range.upperBound)
                                }
                    )
            }
            .onChange(of: value) { _, newValue in
                normalizedPosition = (newValue - range.lowerBound) / (range.upperBound - range.lowerBound)
            }
            .onChange(of: range) { _, newRange in
                withAnimation(.easeInOut(duration: 0.3)) {
                    normalizedPosition = (value - newRange.lowerBound) / (newRange.upperBound - newRange.lowerBound)
                }
            }
        }
        .frame(width: 300, height: 20)
    }
}


enum RenderingMethod: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case gpu = "GPU (Metal)"
    
    var id: String { self.rawValue }
}

struct MandelbrotView: View {
    @Binding var fractalopt: fractalopt?
    @State private var iterdepth: Double = 20
    @State private var contvis: Bool = true
    @State private var blackbgvis: Bool = false
    @State private var isGen: Bool = false
    @State private var progress: Double = 0.0
    @State private var cancelrend: Bool = false
    @State private var renderingMethod: RenderingMethod = isIntelMac() ? .gpu : .gpu
    @State private var genType: MainContentView.genType = isIntelMac() ? .image : .continuousRender
    @State private var zoomhint: Bool = false
    @EnvironmentObject var cview_wrapper: cview_wrapper
    @EnvironmentObject var coordinator: RendererCoordinator
    
    private let isIntelMacUser: Bool = isIntelMac()
    @State private var showcontwarn: Bool = false
    @State private var showgpuwarn: Bool = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(blackbgvis ? 0.85 : 0)
                .transition(.opacity)
                .ignoresSafeArea()

            if !contvis {
                mandelbrotrendview(
                    renderingMethod: renderingMethod,
                    generationType: genType,
                    iterationDepth: Int(iterdepth),
                    isGenerating: $isGen,
                    progress: $progress,
                    cancelRendering: $cancelrend
                )
                .ignoresSafeArea()
            }

            if contvis {
                MainContentView(
                    iterdepth: $iterdepth,
                    renderingMethod: $renderingMethod,
                    isGen: isGen,
                    generationType: $genType,
                    isIntelMacUser: isIntelMacUser
                )
                .padding(.top, 80)
            }

            if contvis {
                VStack(spacing: 0) {
                    genbuttonView(
                        action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                print("resetting states")
                                contvis = false
                                blackbgvis = true
                                isGen = true
                                progress = 0.0
                                cancelrend = false
                                zoomhint = false
                            }
                        },
                        isDisabled: isIntelMacUser && renderingMethod == .gpu && genType == .continuousRender
                    )
                    .padding(.bottom, 40)
                }
                VStack {
                    Spacer()
                    Group {
                        if showcontwarn {
                            Text("Continuous rendering is not supported on Intel Macs. Use image rendering instead.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 24)
                                .opacity(showcontwarn ? 1 : 0)
                                .allowsHitTesting(false)
                                .background(Color.clear)
                                .transition(.opacity)
                        } else if showgpuwarn {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("GPU rendering is unstable on Intel Macs, it may result in crashes. Use CPU rendering for the most stable experience.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 24)
                            .opacity(showgpuwarn ? 1 : 0)
                            .allowsHitTesting(false)
                            .background(Color.clear)
                            .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .zIndex(1)
            }

            if contvis {
                see_back(
                    action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            print("back pressed")
                            fractalopt = nil
                            cview_wrapper.bgopacity = 1.0
                            cview_wrapper.isPlaying = true
                            contvis = true
                            blackbgvis = false
                            isGen = false
                            progress = 0.0
                            cancelrend = true
                            zoomhint = false
                        }
                    }
                )
            }

            if !contvis && !isGen && genType == .image {
                Text("scroll to zoom out!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(zoomhint ? 0.5 : 0))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                    .transition(.opacity)
                    .onChange(of: zoomhint) { _, newValue in
                        if newValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                withAnimation(.easeOut(duration: 1.0)) {
                                    zoomhint = false
                                }
                            }
                        }
                    }
            }

            if isGen && !contvis && genType == .image {
                ProgressOverlay(progress: progress)
            }

            if !contvis && (!isGen || genType == .continuousRender) {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            see_saveimg(
                                action: {
                                    saveimg()
                                }
                            )
                            see_main(
                                action: {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        print("main menu pressed")
                                        fractalopt = nil
                                        cview_wrapper.bgopacity = 1.0
                                        cview_wrapper.isPlaying = true
                                        blackbgvis = false
                                        contvis = true
                                        isGen = false
                                        progress = 0.0
                                        cancelrend = true
                                        zoomhint = false
                                    }
                                }
                            )
                        }
                        .padding(.bottom, 40)
                        .padding(.trailing, 20)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("mandelbrot appeared")
            withAnimation(.easeInOut(duration: 0.3)) {
                showcontwarn = isIntelMacUser && renderingMethod == .gpu && genType == .continuousRender
                showgpuwarn = isIntelMacUser && renderingMethod == .gpu && genType == .image
            }
        }
        .onDisappear {
            print("mandelbrot disappeared")
            isGen = false
            progress = 0.0
            cancelrend = true
            zoomhint = false
        }
        .onChange(of: isGen) { _, newValue in
            print("isgen changed to: \(newValue), progress: \(progress)")
            if !newValue && genType == .image && !contvis {
                withAnimation(.easeIn(duration: 1.0)) {
                    zoomhint = true
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            print("progress updated to: \(newValue)")
        }
        .onChange(of: cancelrend) { _, newValue in
            print("cancelrend changed to: \(newValue)")
            if newValue {
                zoomhint = false
            }
        }
        .onChange(of: renderingMethod) { _, newValue in
            print("rendering method changed to: \(newValue.rawValue)")
            if isGen {
                cancelrend = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isGen = false
                    progress = 0.0
                    cancelrend = false
                    zoomhint = false
                }
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                showcontwarn = isIntelMacUser && newValue == .gpu && genType == .continuousRender
                showgpuwarn = isIntelMacUser && newValue == .gpu && genType == .image
            }
        }
        .onChange(of: genType) { _, newValue in
            print("generation type changed to: \(newValue.rawValue)")
            zoomhint = false
            withAnimation(.easeInOut(duration: 0.3)) {
                showcontwarn = isIntelMacUser && renderingMethod == .gpu && newValue == .continuousRender
                showgpuwarn = isIntelMacUser && renderingMethod == .gpu && newValue == .image
            }
        }
    }

    private func saveimg() {
        print("saveimage: accessing coordinator, cpuController: \(coordinator.cpucont != nil), gpuController: \(coordinator.gpucont != nil), rendEngineController: \(coordinator.rendcontroller != nil)")

        let controller: NSViewController?
        switch (renderingMethod, genType) {
        case (.cpu, .image):
            controller = coordinator.cpucont
        case (.gpu, .image):
            controller = coordinator.gpucont
        case (_, .continuousRender):
            controller = coordinator.rendcontroller
        }

        guard let viewController = controller else {
            print("saveimage: failed to get view controller for rendering method: \(renderingMethod.rawValue), gentype: \(genType.rawValue)")
            NSAlert(error: RenderingError.contaccessfail).runModal()
            return
        }

        let image = (viewController as? MandelbrotCPUController)?.getRenderedImage() ??
                    (viewController as? MandelbrotGPUController)?.getRenderedImage() ??
                    (viewController as? MandelbrotRendEngineController)?.getRenderedImage()
        guard let image = image else {
            print("saveimage: failed to get rendered image from controller")
            NSAlert(error: RenderingError.noimgavailable).runModal()
            return
        }

        let savepanel = NSSavePanel()
        savepanel.allowedContentTypes = [.png]
        savepanel.nameFieldStringValue = "mandelbrot.png"
        savepanel.title = "Save Fractal Image"
        savepanel.message = "Choose where to save your Mandelbrot image"
        savepanel.canCreateDirectories = true

        savepanel.begin { response in
            if response == .OK, let url = savepanel.url {
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    print("saveimage: failed to convert image to png")
                    NSAlert(error: RenderingError.imgconvfail).runModal()
                    return
                }

                do {
                    try pngData.write(to: url)
                    print("saveimage: image saved successfully to \(url.path)")
                    let alert = NSAlert()
                    alert.messageText = "Success!"
                    alert.informativeText = "Image saved successfully to \(url.path)"
                    alert.runModal()
                } catch {
                    print("saveimage: failed to save image: \(error)")
                    NSAlert(error: RenderingError.savefail(error.localizedDescription)).runModal()
                }
            } else {
                print("saveimage: save operation cancelled")
            }
        }
    }
}




struct mandelbrotrendview: View {
    let renderingMethod: RenderingMethod
    let generationType: MainContentView.genType
    let iterationDepth: Int
    @Binding var isGenerating: Bool
    @Binding var progress: Double
    @Binding var cancelRendering: Bool

    var body: some View {
        Group {
            if generationType == .continuousRender {
                MandelbrotRendEngine(
                    iterdepth: iterationDepth,
                    isgen: $isGenerating,
                    prog: $progress,
                    cancelrend: $cancelRendering
                )
            } else {
                switch renderingMethod {
                case .cpu:
                    MandelbrotGenerator(
                        iterdepth: iterationDepth,
                        isgen: $isGenerating,
                        progress: $progress,
                        cancelrend: $cancelRendering
                    )
                case .gpu:
                    MandelbrotMetal(
                        iterdepth: iterationDepth,
                        isgen: $isGenerating,
                        progress: $progress,
                        cancelrend: $cancelRendering
                    )
                }
            }
        }
    }
}

struct MainContentView: View {
    @Binding var iterdepth: Double
    @Binding var renderingMethod: RenderingMethod
    let isGen: Bool
    @Binding var generationType: genType
    let isIntelMacUser: Bool

    enum genType: String, CaseIterable, Identifiable {
        case image = "Image"
        case continuousRender = "Continuous render"
        var id: String { self.rawValue }
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("Mandelbrot Set")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 3)

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Iteration Depth: \(Int(iterdepth))")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(isDisabled ? 0.4 : 0.9))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                    coolsliderthing(
                        value: $iterdepth,
                        range: 10...(generationType == .continuousRender ? 1000 : 143),
                        step: 1,
                        isDisabled: isGen || (isIntelMacUser && generationType == .continuousRender)
                    )
                    .frame(width: 280)
                    .tint(.white.opacity(0.8))
                }

                VStack(spacing: 1) {
                    Picker("Generation Type", selection: $generationType) {
                        ForEach(genType.allCases) { type in
                            Text(type.rawValue)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white.opacity(0.9))
                    .frame(width: 240, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .onChange(of: generationType) { _, newValue in
                        print("generation type changed to: \(newValue.rawValue)")
                        if newValue == .image {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if iterdepth > 143 {
                                    iterdepth = 143
                                }
                            }
                        } else if newValue == .continuousRender {
                            renderingMethod = .gpu
                        }
                    }

                    Picker("Rendering Method", selection: $renderingMethod) {
                        ForEach(RenderingMethod.allCases) { method in
                            Text(method.rawValue)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white.opacity(generationType == .continuousRender ? 0.5 : 0.9))
                    .frame(width: 240, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .disabled(generationType == .continuousRender)
                    .opacity(generationType == .continuousRender ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: generationType)
                    .onChange(of: renderingMethod) { _, newValue in
                        print("rendering method changed to: \(newValue.rawValue)")
                    }
                }
            }

            Text("zₙ₊₁ = zₙ² + c")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
    }

    private var isDisabled: Bool {
        isGen || (isIntelMacUser && generationType == .continuousRender)
    }
}

struct genbuttonView: View {
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Button(action: action) {
                Text("Generate")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(isDisabled ? 0.4 : 0.7))
                    .foregroundColor(isDisabled ? .gray : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
            .disabled(isDisabled)
            .animation(.easeInOut(duration: 0.3), value: isDisabled)
        }
    }
}

struct see_back: View {
    let action: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: action) {
                    Text("← Back")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 40)
            .padding(.leading, 20)
            Spacer()
        }
    }
}

struct ProgressOverlay: View {
    let progress: Double

    var body: some View {
        VStack {
            Text("Generating...")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)
                .tint(.white.opacity(0.8))
            Text("Progress: \(progress, specifier: "%.2f")")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct see_main: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Main Menu")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.7))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct see_saveimg: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Save Image")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.7))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}


struct SierpinskiView: View {
    @Binding var selectedFractal: fractalopt?
    @State private var iterdepth: Double = 5
    @State private var contentvis: Bool = true
    @State private var blackbgvis: Bool = false
    @EnvironmentObject var cview_wrapper: cview_wrapper

    var body: some View {
        ZStack {
            Color.black
                .opacity(blackbgvis ? 0.85 : 0)
                .transition(.opacity)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Sierpinski Triangle")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)

                HStack {
                    Text("Iteration Depth: \(Int(iterdepth))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    coolsliderthing(value: $iterdepth, range: 1...10, step: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                Text("Recursive subdivision of triangles")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            }
            .padding(.top, 80)
            .opacity(contentvis ? 1 : 0)

            VStack {
                Spacer()
                Button(action: {
                    // do nothing
                }) {
                    Text("Generate")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .foregroundColor(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 10)
                .opacity(contentvis ? 1 : 0)
                .disabled(true)
                Text("Coming soon!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
                    .opacity(contentvis ? 1 : 0)
            }

            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            selectedFractal = nil
                            cview_wrapper.bgopacity = 1.0
                            cview_wrapper.isPlaying = true
                            contentvis = true
                            blackbgvis = false
                        }
                    }) {
                        Text("← Back")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.top, 40)
                .padding(.leading, 20)
                Spacer()
            }
            .opacity(contentvis ? 1 : 0)

            VStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        selectedFractal = nil
                        cview_wrapper.bgopacity = 1.0
                        cview_wrapper.isPlaying = true
                        blackbgvis = false
                    }
                }) {
                    Text("Main Menu")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 40)
                .opacity(contentvis ? 0 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KochView: View {
    @Binding var selectedFractal: fractalopt?
    @State private var iterdepth: Double = 4
    @State private var contvis: Bool = true
    @State private var blackbgvis: Bool = false
    @EnvironmentObject var cview_wrapper: cview_wrapper

    var body: some View {
        ZStack {
            Color.black
                .opacity(blackbgvis ? 0.85 : 0)
                .transition(.opacity)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Koch Snowflake")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)

                HStack {
                    Text("Iteration Depth: \(Int(iterdepth))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    coolsliderthing(value: $iterdepth, range: 1...8, step: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                Text("Recursive line segment replacement")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            }
            .padding(.top, 80)
            .opacity(contvis ? 1 : 0)

            VStack {
                Spacer()
                Button(action: {
                    // do nothing
                }) {
                    Text("Generate")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .foregroundColor(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 10)
                .opacity(contvis ? 1 : 0)
                .disabled(true)
                Text("Coming soon!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
                    .opacity(contvis ? 1 : 0)
            }

            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            selectedFractal = nil
                            cview_wrapper.bgopacity = 1.0
                            cview_wrapper.isPlaying = true
                            contvis = true
                            blackbgvis = false
                        }
                    }) {
                        Text("← Back")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.top, 40)
                .padding(.leading, 20)
                Spacer()
            }
            .opacity(contvis ? 1 : 0)

            VStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        selectedFractal = nil
                        cview_wrapper.bgopacity = 1.0
                        cview_wrapper.isPlaying = true
                        blackbgvis = false
                    }
                }) {
                    Text("Main Menu")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 40)
                .opacity(contvis ? 0 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct JuliaView: View {
    @Binding var selectedFractal: fractalopt?
    @State private var iterdepth: Double = 50
    @State private var contvis: Bool = true
    @State private var blackbgvis: Bool = false
    @EnvironmentObject var cview_wrapper: cview_wrapper

    var body: some View {
        ZStack {
            Color.black
                .opacity(blackbgvis ? 0.85 : 0)
                .transition(.opacity)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Julia Set")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)

                HStack {
                    Text("Iteration Depth: \(Int(iterdepth))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    coolsliderthing(value: $iterdepth, range: 10...100, step: 1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                Text("zₙ₊₁ = zₙ² + c (fixed c)")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
            }
            .padding(.top, 80)
            .opacity(contvis ? 1 : 0)

            VStack {
                Spacer()
                Button(action: {
                    // do nothing
                }) {
                    Text("Generate")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.4))
                        .foregroundColor(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 10)
                .opacity(contvis ? 1 : 0)
                .disabled(true)
                Text("Coming soon!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
                    .opacity(contvis ? 1 : 0)
            }

            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            selectedFractal = nil
                            cview_wrapper.bgopacity = 1.0
                            cview_wrapper.isPlaying = true
                            contvis = true
                            blackbgvis = false
                        }
                    }) {
                        Text("← Back")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.top, 40)
                .padding(.leading, 20)
                Spacer()
            }
            .opacity(contvis ? 1 : 0)

            VStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        selectedFractal = nil
                        cview_wrapper.bgopacity = 1.0
                        cview_wrapper.isPlaying = true
                        blackbgvis = false
                    }
                }) {
                    Text("Main Menu")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 40)
                .opacity(contvis ? 0 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
