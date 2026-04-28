import AppKit
import SceneKit

final class SoothsayerScene: SCNScene {
    static let orthographicScale: CGFloat = 2.0

    let rig = SoothsayerRig()
    let cameraNode = SCNNode()

    override init() {
        super.init()
        background.contents = NSColor.clear

        rootNode.addChildNode(rig.root)
        rig.root.position = SCNVector3(0, 0, 0)

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Self.orthographicScale
        camera.zNear = 0.1
        camera.zFar = 200
        cameraNode.camera = camera
        // Camera y=1.4 + ortho scale 2.0 → visible world y in [-0.6, 3.4].
        // Character sits y in [0, ~1.7]; RGB glow blobs (centered on
        // glowAnchor at y=0.85, ~3.7 tall after pulse) reach y≈2.7 — all
        // in-frame, with headroom above for the speech bubble.
        cameraNode.position = SCNVector3(0, 1.4, 8)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        rootNode.addChildNode(cameraNode)
    }

    required init?(coder: NSCoder) { fatalError() }
}
