import AppKit
import ScreenCaptureKit

enum ScreenCaptureError: Error {
    case noDisplay
    case permissionDenied
    case failed(String)
}

@available(macOS 14.0, *)
final class ScreenCapturer {
    func snapshot(maxDimension: CGFloat = 1024) async throws -> Data {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenCaptureError.permissionDenied
        }

        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }

        let appBundleID = Bundle.main.bundleIdentifier ?? "com.shangy.app"
        let excluded = content.applications.filter { $0.bundleIdentifier == appBundleID }
        let filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])

        let config = SCStreamConfiguration()
        let scale = max(1, min(display.width, display.height) / Int(maxDimension))
        config.width = display.width / max(scale, 1)
        config.height = display.height / max(scale, 1)
        config.showsCursor = false
        config.capturesAudio = false

        do {
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return try jpegData(from: cgImage, maxDimension: maxDimension)
        } catch {
            throw ScreenCaptureError.failed(error.localizedDescription)
        }
    }

    private func jpegData(from cgImage: CGImage, maxDimension: CGFloat) throws -> Data {
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else {
            throw ScreenCaptureError.failed("encode")
        }
        return data
    }
}
