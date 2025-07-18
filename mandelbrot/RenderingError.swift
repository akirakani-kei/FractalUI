import Foundation

enum RenderingError: Error, LocalizedError {
    case contaccessfail
    case noimgavailable
    case imgconvfail
    case savefail(String)

    var errorDescription: String? {
        switch self {
        case .contaccessfail:
            return "failed to access the rendering controller."
        case .noimgavailable:
            return "no image available to save. ensure rendering is complete."
        case .imgconvfail:
            return "failed to convert the image to png."
        case .savefail(let message):
            return "failed to save image: \(message)"
        }
    }
}
