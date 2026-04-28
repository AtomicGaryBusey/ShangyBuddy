import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private let brain = ShangyBrain()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        installPanel()
        brain.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Shangy")
            icon?.isTemplate = true
            button.image = icon
            button.imagePosition = .imageOnly
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
