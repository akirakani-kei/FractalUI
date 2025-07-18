import SwiftUI

class RendererCoordinator: ObservableObject {
    @Published var cpucont: MandelbrotCPUController?
    @Published var gpucont: MandelbrotGPUController?
    @Published var rendcontroller: MandelbrotRendEngineController?
}
