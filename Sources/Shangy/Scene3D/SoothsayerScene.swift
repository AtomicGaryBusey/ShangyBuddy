import AppKit
import SceneKit

final class SoothsayerScene: SCNScene {
    static let orthographicScale: CGFloat = 1.45

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
        cameraNode.position = SCNVector3(0, 0.95, 8)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        rootNode.addChildNode(cameraNode)
    }

    required init?(coder: NSCoder) { fatalError() }
}
