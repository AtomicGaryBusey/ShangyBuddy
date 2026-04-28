import AppKit
import SceneKit
import SwiftUI

struct SceneHostView: NSViewRepresentable {
    let scene: SoothsayerScene
    let onPositionChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.wantsLayer = true
        view.delegate = context.coordinator
        context.coordinator.view = view
        context.coordinator.onPositionChange = onPositionChange
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.onPositionChange = onPositionChange
    }

    func makeCoordinator() -> Coordinator { Coordinator(scene: scene) }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let scene: SoothsayerScene
        weak var view: SCNView?
        var onPositionChange: ((CGFloat) -> Void)?

        init(scene: SoothsayerScene) { self.scene = scene }

        func renderer(_ renderer: SCNSceneRenderer, didRenderScene s: SCNScene, atTime time: TimeInterval) {
            guard let view = view else { return }
            let world = scene.rig.root.presentation.position
            let projected = renderer.projectPoint(SCNVector3(world.x, 0.6, world.z))
            let normalized = CGFloat(projected.x) / max(view.bounds.width, 1)
            DispatchQueue.main.async { [weak self] in
                self?.onPositionChange?(normalized)
            }
        }
    }
}
