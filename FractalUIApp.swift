import SwiftUI

@main
struct FractalUIApp: App {
    @StateObject private var contentViewWrapper = cview_wrapper()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(contentViewWrapper)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.styleMask.insert(.fullSizeContentView)
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .hidden

                        let defaultSize = CGSize(width: 900, height: 635)
                        let defaultFrame = NSRect(
                            origin: window.frame.origin,
                            size: defaultSize
                        )
                        window.setFrame(defaultFrame, display: true, animate: false)
                        
                        window.minSize = defaultSize
                        window.maxSize = defaultSize
                        
                        window.center()

                        window.collectionBehavior.insert(.fullScreenNone)

                        print("Window size set to: \(window.frame.size)")
                    }
                }
        }
    }
}
