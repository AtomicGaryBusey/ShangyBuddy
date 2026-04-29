import AppKit
import SceneKit
import simd

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

    /// While true, walk/idle pose updates skip the right arm so a one-shot
    /// gesture (proclaim) is not overwritten on every tick.
    var armsLocked: Bool = false

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

        let shoulderY: CGFloat = 0.22
        configureArm(leftArm, length: 0.62, parent: torso, anchor: SCNVector3(-0.34, shoulderY, 0), material: silhouette, mirrored: true)
        configureArm(rightArm, length: 0.62, parent: torso, anchor: SCNVector3(0.34, shoulderY, 0), material: silhouette, mirrored: false)

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
        // Anchor sits low on the skull so the hair's volume floats above and
        // around the head rather than starting from the crown.
        hair.position = SCNVector3(0, 0.04, -0.02)
        head.addChildNode(hair)

        // Main mass — wider than the head, slightly squashed front-to-back.
        let mass = SCNNode(geometry: SCNSphere(radius: 0.30))
        mass.geometry?.firstMaterial = material
        mass.scale = SCNVector3(1.30, 1.05, 1.10)
        mass.position = SCNVector3(0, 0.10, -0.03)
        hair.addChildNode(mass)

        // Camera looks down -Z from +Z, so +Z is the front of the character
        // (where the face/glasses live). Anything pointing toward +Z occludes
        // the glasses. Reject any candidate whose radial direction has
        // radial.z > frontThreshold so spikes/clumps stay on top, sides, and
        // back of the head only.
        let frontThreshold: Float = 0.30

        // Secondary lumpy clumps that bulge out so the hair silhouette
        // doesn't read as a smooth helmet.
        var clumps = 0
        var clumpAttempts = 0
        while clumps < 5 && clumpAttempts < 80 {
            clumpAttempts += 1
            let theta = CGFloat.random(in: 0...(2 * .pi))
            let phi = CGFloat.random(in: 0.10...(0.65 * .pi))
            let zComp = Float(sin(phi) * sin(theta))
            if zComp > frontThreshold { continue }
            let dist: CGFloat = 0.30
            let clump = SCNNode(geometry: SCNSphere(radius: CGFloat.random(in: 0.10...0.16)))
            clump.geometry?.firstMaterial = material
            clump.position = SCNVector3(
                dist * sin(phi) * cos(theta),
                0.10 + dist * cos(phi),
                -0.03 + dist * sin(phi) * sin(theta)
            )
            clump.scale = SCNVector3(
                CGFloat.random(in: 0.85...1.15),
                CGFloat.random(in: 0.75...1.10),
                CGFloat.random(in: 0.85...1.15)
            )
            hair.addChildNode(clump)
            clumps += 1
        }

        // Tendrils radiating outward — top, sides, and back only.
        var spikes = 0
        var spikeAttempts = 0
        while spikes < 30 && spikeAttempts < 200 {
            spikeAttempts += 1
            let theta = CGFloat.random(in: 0...(2 * .pi))
            // Bias phi toward the top (smaller phi) but allow sideways spikes.
            let phiBase = CGFloat.random(in: 0...1)
            let phi = phiBase * phiBase * 0.85 * .pi

            let radial = simd_normalize(simd_float3(
                Float(sin(phi) * cos(theta)),
                Float(cos(phi)),
                Float(sin(phi) * sin(theta))
            ))
            // Skip front-facing spikes — they'd block the glasses.
            if radial.z > frontThreshold { continue }

            let spikeLen = CGFloat.random(in: 0.22...0.50)
            let baseRadius: CGFloat = 0.30 + CGFloat.random(in: 0...0.04)
            let cone = SCNCone(
                topRadius: 0.002,
                bottomRadius: CGFloat.random(in: 0.018...0.030),
                height: spikeLen
            )
            cone.firstMaterial = material
            let n = SCNNode(geometry: cone)

            let centerDist = baseRadius + spikeLen / 2
            n.position = SCNVector3(
                CGFloat(radial.x) * centerDist,
                0.10 + CGFloat(radial.y) * centerDist,
                -0.03 + CGFloat(radial.z) * centerDist
            )
            n.simdOrientation = orientationToAlignY(with: radial)

            // Small random twist so spikes don't all sit on a perfect radial.
            let jitterAxis = simd_normalize(simd_float3(
                Float.random(in: -1...1),
                Float.random(in: -1...1),
                Float.random(in: -1...1)
            ))
            let jitter = simd_quatf(angle: Float.random(in: -0.20...0.20), axis: jitterAxis)
            n.simdOrientation = jitter * n.simdOrientation
            hair.addChildNode(n)
            spikes += 1
        }

        // Front fringe — short spikes that emerge from the top of the
        // forehead and angle up+forward. phi kept small so the spike base
        // sits high on the skull (well above the glasses) and the tip
        // travels further upward than forward.
        for _ in 0..<5 {
            let theta: CGFloat = .pi / 2 + CGFloat.random(in: -0.4...0.4)
            let phi: CGFloat = CGFloat.random(in: 0.20...0.45)

            let radial = simd_normalize(simd_float3(
                Float(sin(phi) * cos(theta)),
                Float(cos(phi)),
                Float(sin(phi) * sin(theta))
            ))

            let spikeLen = CGFloat.random(in: 0.28...0.42)
            let cone = SCNCone(topRadius: 0.002, bottomRadius: 0.022, height: spikeLen)
            cone.firstMaterial = material
            let n = SCNNode(geometry: cone)
            let baseRadius: CGFloat = 0.30
            let centerDist = baseRadius + spikeLen / 2
            n.position = SCNVector3(
                CGFloat(radial.x) * centerDist,
                0.10 + CGFloat(radial.y) * centerDist,
                -0.03 + CGFloat(radial.z) * centerDist
            )
            n.simdOrientation = orientationToAlignY(with: radial)
            hair.addChildNode(n)
        }
    }

    /// Quaternion that rotates the local +Y axis to point along `target`.
    /// Cones in SceneKit have their height along +Y, so this aligns a cone
    /// (base→tip) with an arbitrary direction vector.
    private func orientationToAlignY(with target: simd_float3) -> simd_quatf {
        let up = simd_float3(0, 1, 0)
        let dotP = max(-1, min(1, simd_dot(up, target)))
        if dotP > 0.9999 {
            return simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
        }
        if dotP < -0.9999 {
            // Antiparallel — rotate 180° around any perpendicular axis.
            return simd_quatf(angle: .pi, axis: simd_float3(1, 0, 0))
        }
        let axis = simd_normalize(simd_cross(up, target))
        let angle = acos(dotP)
        return simd_quatf(angle: angle, axis: axis)
    }

    // MARK: - Glasses

    private func installGlasses(on head: SCNNode, frame: SCNMaterial, lens: SCNMaterial) {
        glasses.position = SCNVector3(0, 0.02, 0.18)

        let lensWidth: CGFloat = 0.13
        let lensHeight: CGFloat = 0.10
        let frameThickness: CGFloat = 0.018
        let depth: CGFloat = 0.02

        for sign: CGFloat in [-1, 1] {
            let center = SCNVector3(sign * 0.075, 0, 0)
            let lensFill = SCNNode(geometry: SCNBox(
                width: lensWidth, height: lensHeight, length: depth * 0.5, chamferRadius: 0.012
            ))
            lensFill.geometry?.firstMaterial = lens
            lensFill.position = center
            glasses.addChildNode(lensFill)

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

        let outward: CGFloat = mirrored ? 0.10 : -0.10
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
        let colors: [(NSColor, CGFloat)] = [
            (NSColor(calibratedRed: 1.0, green: 0.15, blue: 0.35, alpha: 1), 0),
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

            let radius: CGFloat = 0.55
            let period: CGFloat = 7.0
            let orbit = SCNAction.customAction(duration: TimeInterval(period)) { node, elapsed in
                let t = phase + (elapsed / period) * 2 * .pi
                node.position = SCNVector3(
                    radius * cos(t),
                    radius * 0.55 * sin(t),
                    0
                )
            }
            plane.runAction(SCNAction.repeatForever(orbit))

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
        // Lean ~30° toward direction of travel — keeps glasses/hair silhouette
        // legible (vs. full profile) while clearly indicating heading.
        let target: CGFloat = (facing == .right) ? .pi * 0.18 : -.pi * 0.18
        body.eulerAngles = SCNVector3(0, target, 0)
    }

    func setLegSwing(phase: Double) {
        let swing = CGFloat(sin(phase)) * 0.55
        leftLeg.eulerAngles = SCNVector3(swing, 0, 0)
        rightLeg.eulerAngles = SCNVector3(-swing, 0, 0)
    }

    func setArmSwing(phase: Double) {
        let swing = CGFloat(sin(phase)) * 0.45
        leftArm.eulerAngles = SCNVector3(-swing, 0, .pi * 0.04)
        if !armsLocked {
            rightArm.eulerAngles = SCNVector3(swing, 0, -.pi * 0.04)
        }
    }

    func setBob(phase: Double) {
        let bob = CGFloat(abs(sin(phase * 2))) * 0.04
        torso.position.y = 0.30 + bob
    }

    func setIdleSway(phase: Double) {
        let sway = CGFloat(sin(phase)) * 0.06
        torso.eulerAngles.z = sway * 0.4
        leftArm.eulerAngles = SCNVector3(0, 0, .pi * 0.08 + sway * 0.25)
        if !armsLocked {
            rightArm.eulerAngles = SCNVector3(0, 0, -.pi * 0.08 - sway * 0.25)
        }
    }

    func proclaim() -> SCNAction {
        return SCNAction.run { [weak self] _ in
            guard let self else { return }
            self.armsLocked = true
            let raise = SCNAction.rotateTo(x: -.pi * 0.55, y: 0, z: -.pi * 0.20, duration: 0.35)
            raise.timingMode = .easeInEaseOut
            let hold = SCNAction.wait(duration: 0.6)
            let lower = SCNAction.rotateTo(x: 0, y: 0, z: -.pi * 0.05, duration: 0.4)
            lower.timingMode = .easeInEaseOut
            let unlock = SCNAction.run { [weak self] _ in self?.armsLocked = false }
            self.rightArm.runAction(SCNAction.sequence([raise, hold, lower, unlock]))
        }
    }
}
