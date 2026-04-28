import Foundation
import SceneKit

/// Drives the rig's per-frame pose. All public methods and the display-link
/// callback land on the main thread; nothing here is touched from elsewhere.
final class WalkCycle {
    private let rig: SoothsayerRig
    private var displayLink: CVDisplayLink?
    private var startTime: CFTimeInterval = 0
    private var modeStartedAt: CFTimeInterval = 0
    private var mode: Mode = .walking
    private var direction: Double = 1
    private var bounds: ClosedRange<Double> = -3.5...3.5
    private var nextModeChangeAt: CFTimeInterval = 0

    var positionX: Double = -3.0

    enum Mode {
        case walking
        case paused
        case gesturing
    }

    init(rig: SoothsayerRig) {
        self.rig = rig
        rig.facing = .right
        scheduleNextModeChange(now: 0)
    }

    func setStageWidth(_ width: Double) {
        let half = max(1.0, width / 2 - 0.6)
        bounds = -half...half
        positionX = max(min(positionX, bounds.upperBound), bounds.lowerBound)
    }

    func start() {
        guard displayLink == nil else { return }
        startTime = CACurrentMediaTime()
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        displayLink = link
        let cb: CVDisplayLinkOutputCallback = { _, _, _, _, _, ctx in
            guard let ctx else { return kCVReturnSuccess }
            let cycle = Unmanaged<WalkCycle>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { cycle.tick() }
            return kCVReturnSuccess
        }
        CVDisplayLinkSetOutputCallback(link, cb, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
    }

    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            CVDisplayLinkSetOutputCallback(link, nil, nil)
        }
        displayLink = nil
    }

    deinit {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            CVDisplayLinkSetOutputCallback(link, nil, nil)
        }
    }

    func gesture() {
        rig.root.runAction(rig.proclaim())
    }

    private func tick() {
        let now = CACurrentMediaTime() - startTime
        if now >= nextModeChangeAt {
            advanceMode(now: now)
        }
        switch mode {
        case .walking:
            stepWalking(now: now)
        case .paused:
            stepPaused(now: now)
        case .gesturing:
            stepGesturing(now: now)
        }
        rig.root.position = SCNVector3(positionX, 0, 0)
    }

    private func stepWalking(now: CFTimeInterval) {
        let speed = 0.85
        positionX += direction * speed * (1.0 / 60.0)
        if positionX >= bounds.upperBound {
            positionX = bounds.upperBound
            direction = -1
            rig.facing = .left
        } else if positionX <= bounds.lowerBound {
            positionX = bounds.lowerBound
            direction = 1
            rig.facing = .right
        }
        let phase = now * 5.5
        rig.setLegSwing(phase: phase)
        rig.setArmSwing(phase: phase)
        rig.setBob(phase: phase)
    }

    private func stepPaused(now: CFTimeInterval) {
        let phase = (now - modeStartedAt) * 1.4
        rig.setIdleSway(phase: phase)
        rig.setLegSwing(phase: 0)
        rig.setBob(phase: phase * 0.5)
    }

    private func stepGesturing(now: CFTimeInterval) {
        stepPaused(now: now)
    }

    private func advanceMode(now: CFTimeInterval) {
        modeStartedAt = now
        switch mode {
        case .walking:
            mode = Bool.random() ? .paused : .gesturing
            if mode == .gesturing { rig.root.runAction(rig.proclaim()) }
        case .paused, .gesturing:
            mode = .walking
            if Bool.random() {
                direction *= -1
                rig.facing = (direction > 0) ? .right : .left
            }
        }
        scheduleNextModeChange(now: now)
    }

    private func scheduleNextModeChange(now: CFTimeInterval) {
        let duration: CFTimeInterval
        switch mode {
        case .walking: duration = .random(in: 4...9)
        case .paused: duration = .random(in: 2.5...5)
        case .gesturing: duration = .random(in: 1.4...2.4)
        }
        nextModeChangeAt = now + duration
    }
}
