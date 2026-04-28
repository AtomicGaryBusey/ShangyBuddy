import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class ShangyBrain: ObservableObject {
    @Published private(set) var currentLine: String?
    @Published private(set) var isThinking: Bool = false

    let scene = SoothsayerScene()
    lazy var walkCycle: WalkCycle = WalkCycle(rig: scene.rig)

    private let ollama = OllamaClient()
    private let capturer: ScreenCapturer? = {
        if #available(macOS 14.0, *) { return ScreenCapturer() } else { return nil }
    }()

    private var loopTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var lastLineAt: Date = .distantPast

    func start() {
        walkCycle.start()
        scheduleNextProphecy(initialDelay: 4)
    }

    func stop() {
        loopTask?.cancel()
        walkCycle.stop()
    }

    func prophesizeNow() async {
        await produceProphecy()
    }

    private func scheduleNextProphecy(initialDelay: TimeInterval) {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            while !Task.isCancelled {
                await self?.produceProphecy()
                let wait = Double.random(in: 35...75)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }

    private func produceProphecy() async {
        guard !isThinking else { return }
        isThinking = true
        defer { isThinking = false }

        var image: Data? = nil
        if let capturer {
            image = try? await capturer.snapshot()
        }

        let prophecy: String
        do {
            prophecy = try await ollama.generate(
                systemPrompt: Persona.system,
                userPrompt: image == nil ? "Issue one cryptic prophecy. No preamble." : Persona.userPrompt,
                image: image
            )
        } catch {
            prophecy = Persona.fallbackBlind.randomElement() ?? "The omens are quiet."
        }

        let cleaned = sanitize(prophecy)
        guard !cleaned.isEmpty else { return }

        walkCycle.gesture()
        currentLine = cleaned
        lastLineAt = .now

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            await MainActor.run {
                guard let self else { return }
                if Date().timeIntervalSince(self.lastLineAt) >= 8.5 {
                    self.currentLine = nil
                }
            }
        }
    }

    private func sanitize(_ text: String) -> String {
        let stripped = text
            .replacingOccurrences(of: "^\\s*[\"']", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\"']\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = stripped.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? stripped
        return String(firstLine.prefix(180))
    }
}
