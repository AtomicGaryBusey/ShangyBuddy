import AppKit
import SceneKit

final class SoothsayerRig {
    let root = SCNNode()
    let body = SCNNode()
    let pelvis = SCNNode()
    let torso = SCNNode()
    let head = SCNNode()
    let hair = SCNNode()
    let glasses = SCNNode()
    let leftArm = SCNNode()
    let rightArm = SCNNode()
    let leftLeg = SCNNode()
    let rightLeg = SCNNode()
    let glowAnchor = SCNNode()

    var facing: Facing = .right { didSet { applyFacing() } }
    enum Facing { case left, right }

    init() {
        build()
    }

    private func build() {
        let silhouette = silhouetteMaterial()
        let frameMaterial = whiteFrameMaterial()

        root.addChildNode(glowAnchor)
        glowAnchor.position = SCNVector3(0, 0.85, -0.4)
        installRGBBacklight(on: glowAnchor)

        root.addChildNode(body)
        body.position = SCNVector3(0, 0, 0)

        body.addChildNode(pelvis)
        pelvis.position = SCNVector3(0, 0.62, 0)

        let torsoGeo = SCNBox(width: 0.62, height: 0.58, length: 0.30, chamferRadius: 0.10)
        torsoGeo.firstMaterial = silhouette
        torso.geometry = torsoGeo
        torso.position = SCNVector3(0, 0.30, 0)
        pelvis.addChildNode(torso)

        let neck = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 0.06))
        neck.geometry?.firstMaterial = silhouette
        neck.position = SCNVector3(0, 0.34, 0)
        torso.addChildNode(neck)

        let headGeo = SCNSphere(radius: 0.20)
        headGeo.firstMaterial = silhouette
        head.geometry = headGeo
        head.scale = SCNVector3(1.0, 1.05, 0.95)
        head.position = SCNVector3(0, 0.50, 0)
        torso.addChildNode(head)

        installSpikyHair(on: head, material: silhouette)
        installGlasses(on: head, frame: frameMaterial, lens: silhouette)
        head.addChildNode(glasses)

        // Arms — pivot at shoulder, hang down with slight outward angle.
        let shoulderY: CGFloat = 0.22
        configureArm(leftArm, length: 0.62, parent: torso, anchor: SCNVector3(-0.34, shoulderY, 0), material: silhouette, mirrored: true)
        configureArm(rightArm, length: 0.62, parent: torso, anchor: SCNVector3(0.34, shoulderY, 0), material: silhouette, mirrored: false)

        // Legs — baggy joggers, sneakers at the bottom.
        configureLeg(leftLeg, length: 0.60, parent: pelvis, anchor: SCNVector3(-0.14, 0, 0), material: silhouette)
        configureLeg(rightLeg, length: 0.60, parent: pelvis, anchor: SCNVector3(0.14, 0, 0), material: silhouette)

        applyFacing()
    }

    // MARK: - Materials

    private func silhouetteMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = NSColor.black
        m.isDoubleSided = false
        m.writesToDepthBuffer = true
        m.readsFromDepthBuffer = true
        return m
    }

    private func whiteFrameMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = NSColor.white
        m.emission.contents = NSColor(calibratedWhite: 0.85, alpha: 1)
        return m
    }

    // MARK: - Hair

    private func installSpikyHair(on head: SCNNode, material: SCNMaterial) {
        hair.position = SCNVector3(0, 0.10, -0.02)
        head.addChildNode(hair)

        // Big base mass of hair
        let mass = SCNNode(geometry: SCNSphere(radius: 0.22))
        mass.geometry?.firstMaterial = material
        mass.scale = SCNVector3(1.05, 0.95, 1.0)
        mass.position = SCNVector3(0, 0.05, 0)
        hair.addChildNode(mass)

        // Spikes radiating up and outward
        let count = 22
        for i in 0..<count {
            let theta = (Double(i) / Double(count)) * .pi * 2
            let lift = Double.random(in: 0.18...0.42)
            let spikeLen = CGFloat.random(in: 0.18...0.40)
            let radius = CGFloat.random(in: 0.05...0.18)
            let cone = SCNCone(topRadius: 0.005, bottomRadius: 0.04, height: spikeLen)
            cone.firstMaterial = material
            let n = SCNNode(geometry: cone)
            let baseX = radius * cos(theta)
            let baseZ = radius * sin(theta) * 0.8
            n.position = SCNVector3(baseX, 0.10 + lift * 0.25, baseZ)
            // Tilt outward and upward
            n.eulerAngles = SCNVector3(
                Float(-sin(theta) * 0.6),
                Float.random(in: -0.4...0.4),
                Float(cos(theta) * 0.6)
            )
            hair.addChildNode(n)
        }

        // A few tall front spikes
        for _ in 0..<4 {
            let spikeLen = CGFloat.random(in: 0.30...0.50)
            let cone = SCNCone(topRadius: 0.004, bottomRadius: 0.035, height: spikeLen)
            cone.firstMaterial = material
            let n = SCNNode(geometry: cone)
            n.position = SCNVector3(
                CGFloat.random(in: -0.10...0.10),
                0.20,
                CGFloat.random(in: 0.04...0.10)
            )
            n.eulerAngles = SCNVector3(
                Float.random(in: -0.4 ... -0.1),
                Float.random(in: -0.3...0.3),
                Float.random(in: -0.3...0.3)
            )
            hair.addChildNode(n)
        }
    }

    // MARK: - Glasses

    private func installGlasses(on head: SCNNode, frame: SCNMaterial, lens: SCNMaterial) {
        glasses.position = SCNVector3(0, 0.02, 0.18)

        let lensWidth: CGFloat = 0.13
        let lensHeight: CGFloat = 0.10
        let frameThickness: CGFloat = 0.018
        let depth: CGFloat = 0.02

        for sign in [-1.0, 1.0] {
            let center = SCNVector3(CGFloat(sign) * 0.075, 0, 0)
            let lensFill = SCNNode(geometry: SCNBox(
                width: lensWidth, height: lensHeight, length: depth * 0.5, chamferRadius: 0.012
            ))
            lensFill.geometry?.firstMaterial = lens
            lensFill.position = center
            glasses.addChildNode(lensFill)

            // Frame: 4 bars (top, bottom, left, right)
            let halfW = lensWidth / 2
            let halfH = lensHeight / 2
            let bars: [(SCNVector3, CGFloat, CGFloat)] = [
                (SCNVector3(center.x, center.y + halfH, center.z), lensWidth + frameThickness * 2, frameThickness),
                (SCNVector3(center.x, center.y - halfH, center.z), lensWidth + frameThickness * 2, frameThickness),
                (SCNVector3(center.x - halfW, center.y, center.z), frameThickness, lensHeight),
                (SCNVector3(center.x + halfW, center.y, center.z), frameThickness, lensHeight)
            ]
            for (pos, w, h) in bars {
                let bar = SCNNode(geometry: SCNBox(width: w, height: h, length: depth, chamferRadius: 0.003))
                bar.geometry?.firstMaterial = frame
                bar.position = pos
                glasses.addChildNode(bar)
            }
        }

        // Bridge between lenses
        let bridge = SCNNode(geometry: SCNBox(width: 0.04, height: frameThickness, length: depth, chamferRadius: 0.002))
        bridge.geometry?.firstMaterial = frame
        bridge.position = SCNVector3(0, 0, 0)
        glasses.addChildNode(bridge)
    }

    // MARK: - Limbs

    private func configureArm(
        _ limb: SCNNode,
        length: CGFloat,
        parent: SCNNode,
        anchor: SCNVector3,
        material: SCNMaterial,
        mirrored: Bool
    ) {
        limb.position = anchor
        let upper = SCNCone(topRadius: 0.075, bottomRadius: 0.06, height: length * 0.55)
        upper.firstMaterial = material
        let upperNode = SCNNode(geometry: upper)
        upperNode.position = SCNVector3(0, -length * 0.55 / 2, 0)
        limb.addChildNode(upperNode)

        let forearm = SCNCone(topRadius: 0.06, bottomRadius: 0.05, height: length * 0.45)
        forearm.firstMaterial = material
        let forearmNode = SCNNode(geometry: forearm)
        forearmNode.position = SCNVector3(0, -length * 0.55 - length * 0.45 / 2 + 0.02, 0)
        limb.addChildNode(forearmNode)

        let hand = SCNNode(geometry: SCNSphere(radius: 0.06))
        hand.geometry?.firstMaterial = material
        hand.position = SCNVector3(0, -length + 0.02, 0)
        limb.addChildNode(hand)

        // Slight outward resting tilt
        let outward: Float = mirrored ? 0.10 : -0.10
        limb.eulerAngles = SCNVector3(0, 0, outward)
        parent.addChildNode(limb)
    }

    private func configureLeg(
        _ limb: SCNNode,
        length: CGFloat,
        parent: SCNNode,
        anchor: SCNVector3,
        material: SCNMaterial
    ) {
        limb.position = anchor
        let leg = SCNCone(topRadius: 0.13, bottomRadius: 0.10, height: length)
        leg.firstMaterial = material
        let legNode = SCNNode(geometry: leg)
        legNode.position = SCNVector3(0, -length / 2, 0)
        limb.addChildNode(legNode)

        let shoe = SCNNode(geometry: SCNBox(width: 0.20, height: 0.07, length: 0.30, chamferRadius: 0.025))
        shoe.geometry?.firstMaterial = material
        shoe.position = SCNVector3(0, -length - 0.005, 0.03)
        limb.addChildNode(shoe)

        parent.addChildNode(limb)
    }

    // MARK: - Backlight

    private func installRGBBacklight(on anchor: SCNNode) {
        let colors: [(NSColor, Double)] = [
            (NSColor(calibratedRed: 1.0, green: 0.15, blue: 0.35, alpha: 1), 0.0),
            (NSColor(calibratedRed: 0.15, green: 1.0, blue: 0.40, alpha: 1), 2 * .pi / 3),
            (NSColor(calibratedRed: 0.20, green: 0.45, blue: 1.0, alpha: 1), 4 * .pi / 3)
        ]

        for (color, phase) in colors {
            let plane = SCNNode(geometry: SCNPlane(width: 3.4, height: 3.4))
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = radialBlob(color: color)
            mat.blendMode = .add
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = false
            mat.isDoubleSided = true
            plane.geometry?.firstMaterial = mat
            plane.renderingOrder = -10
            anchor.addChildNode(plane)

            // Orbit slowly to create cycling RGB cloud.
            let radius: CGFloat = 0.55
            let period: CFTimeInterval = 7.0
            let orbit = SCNAction.customAction(duration: period) { node, elapsed in
                let t = phase + (Double(elapsed) / period) * 2 * .pi
                node.position = SCNVector3(
                    radius * CGFloat(cos(t)),
                    radius * 0.55 * CGFloat(sin(t)),
                    0
                )
            }
            plane.runAction(SCNAction.repeatForever(orbit))

            // Subtle pulse.
            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.10, duration: 1.6),
                SCNAction.scale(to: 0.92, duration: 1.6)
            ])
            pulse.timingMode = .easeInEaseOut
            plane.runAction(SCNAction.repeatForever(pulse))
        }
    }

    private func radialBlob(color: NSColor) -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let img = NSImage(size: size)
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let stops: [CGFloat] = [0, 0.55, 1]
            let cgColors = [
                color.withAlphaComponent(0.95).cgColor,
                color.withAlphaComponent(0.35).cgColor,
                color.withAlphaComponent(0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space, colors: cgColors, locations: stops)!
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 128, y: 128), startRadius: 0,
                endCenter: CGPoint(x: 128, y: 128), endRadius: 128,
                options: []
            )
        }
        img.unlockFocus()
        return img
    }

    // MARK: - Pose

    private func applyFacing() {
        let target: Float = (facing == .right) ? .pi * 0.06 : -.pi * 0.06
        body.eulerAngles = SCNVector3(0, target, 0)
    }

    func setLegSwing(phase: Double) {
        let swing = Float(sin(phase)) * 0.55
        leftLeg.eulerAngles = SCNVector3(swing, 0, 0)
        rightLeg.eulerAngles = SCNVector3(-swing, 0, 0)
    }

    func setArmSwing(phase: Double) {
        let swing = Float(sin(phase)) * 0.45
        leftArm.eulerAngles = SCNVector3(-swing, 0, Float.pi * 0.04)
        rightArm.eulerAngles = SCNVector3(swing, 0, -Float.pi * 0.04)
    }

    func setBob(phase: Double) {
        let bob = Float(abs(sin(phase * 2))) * 0.04
        torso.position.y = 0.30 + bob
    }

    func setIdleSway(phase: Double) {
        let sway = Float(sin(phase)) * 0.06
        torso.eulerAngles.z = sway * 0.4
        leftArm.eulerAngles = SCNVector3(0, 0, Float.pi * 0.08 + sway * 0.25)
        rightArm.eulerAngles = SCNVector3(0, 0, -Float.pi * 0.08 - sway * 0.25)
    }

    func proclaim() -> SCNAction {
        let raise = SCNAction.rotateTo(x: -.pi * 0.55, y: 0, z: -.pi * 0.20, duration: 0.35)
        raise.timingMode = .easeInEaseOut
        let hold = SCNAction.wait(duration: 0.6)
        let lower = SCNAction.rotateTo(x: 0, y: 0, z: -.pi * 0.05, duration: 0.4)
        lower.timingMode = .easeInEaseOut
        let seq = SCNAction.sequence([raise, hold, lower])
        return SCNAction.run { [weak self] _ in
            self?.rightArm.runAction(seq)
        }
    }
}
