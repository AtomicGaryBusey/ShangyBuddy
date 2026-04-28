import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private let brain = ShangyBrain()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = makeAppIcon()
        installStatusItem()
        installPanel()
        // Trigger the Screen Recording prompt exactly once at launch if we
        // don't already hold permission. ScreenCaptureKit calls past this
        // point are gated on CGPreflightScreenCaptureAccess(), so we never
        // re-pop the TCC dialog mid-session.
        if #available(macOS 14.0, *), !ScreenCapturer.hasPermission() {
            ScreenCapturer.requestPermission()
        }
        brain.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Builds the Dock icon at runtime — purple gradient rounded square with
    /// a sparkles glyph in white. Avoids shipping an .icns binary.
    private func makeAppIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let icon = NSImage(size: size)
        icon.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 110, yRadius: 110)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.45, green: 0.10, blue: 0.65, alpha: 1),
            NSColor(calibratedRed: 0.08, green: 0.02, blue: 0.20, alpha: 1)
        ])
        gradient?.draw(in: path, angle: 270)

        if let sparkles = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 320, weight: .regular)
            let sized = sparkles.withSymbolConfiguration(config) ?? sparkles
            let symSize = sized.size
            let centered = NSRect(
                x: (size.width - symSize.width) / 2,
                y: (size.height - symSize.height) / 2,
                width: symSize.width,
                height: symSize.height
            )
            // Tint the template symbol white.
            NSColor.white.set()
            sized.draw(in: centered, from: .zero, operation: .sourceAtop, fraction: 0.95)
        }

        icon.unlockFocus()
        return icon
    }

    private func installPanel() {
        let view = SoothsayerView()
            .environmentObject(brain)
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false

        panel = FloatingPanel(contentRect: panelFrame())
        panel.contentView = host
        panel.setFrame(panelFrame(), display: true)
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        applyStageBounds()
    }

    private func panelFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: 1200, height: 480)
        }
        let frame = screen.frame
        let height: CGFloat = 480
        return NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: height)
    }

    private func applyStageBounds() {
        let viewWidth = Double(panel.frame.width)
        let viewHeight = Double(panel.frame.height)
        guard viewHeight > 0 else { return }
        let aspect = viewWidth / viewHeight
        // Orthographic camera: visible vertical extent = 2 * orthoScale,
        // visible horizontal extent = 2 * orthoScale * aspect.
        let visibleWorldWidth = 2.0 * Double(SoothsayerScene.orthographicScale) * aspect
        brain.walkCycle.setStageWidth(visibleWorldWidth)
    }

    @objc private func screenChanged() {
        panel.setFrame(panelFrame(), display: true)
        applyStageBounds()
    }

    private func installStatusItem() {
        // squareLength guarantees a visible width even if the icon fails to load.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let icon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Shangy") {
                icon.isTemplate = true
                button.image = icon
                button.imagePosition = .imageOnly
            } else {
                // Fallback so the menu is always reachable.
                button.title = "✶"
            }
            button.toolTip = "Shangy — click for menu"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Speak Now", action: #selector(speakNow), keyEquivalent: "s").target = self
        menu.addItem(withTitle: "Toggle Visibility", action: #selector(toggleVisibility), keyEquivalent: "h").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Shangy", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func speakNow() {
        Task { await brain.prophesizeNow() }
    }

    @objc private func toggleVisibility() {
        panel.setIsVisible(!panel.isVisible)
    }

    @objc private func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
