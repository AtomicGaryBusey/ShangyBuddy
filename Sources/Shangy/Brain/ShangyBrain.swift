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

        let prophecy = await consult()

        let cleaned = sanitize(prophecy)
        guard !cleaned.isEmpty else { return }

        walkCycle.gesture()
        currentLine = cleaned
        lastLineAt = .now

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self else { return }
                if Task.isCancelled { return }
                if Date().timeIntervalSince(self.lastLineAt) >= 8.5 {
                    self.currentLine = nil
                }
            }
        }
    }

    /// Captures a screenshot, sends it to Ollama, returns the prophecy string.
    /// Scoped so the screenshot `Data` (and the base64-encoded copy inside the
    /// request body) goes out of scope and is released the moment this call
    /// returns — it does not outlive the speech-bubble lifetime.
    private func consult() async -> String {
        var image: Data? = nil
        if let capturer {
            image = try? await capturer.snapshot()
        }
        defer { image = nil }

        do {
            return try await ollama.generate(
                systemPrompt: Persona.system,
                userPrompt: image == nil ? "Issue one cryptic prophecy. No preamble." : Persona.userPrompt,
                image: image
            )
        } catch {
            return Persona.fallbackBlind.randomElement() ?? "The omens are quiet."
        }
    }

    private func sanitize(_ text: String) -> String {
        // Strip control chars and default-ignorable code points (e.g. RTL
        // override U+202E) so the model can't slip weird formatting into the
        // bubble or into anything that later logs the string.
        let cleanedScalars = text.unicodeScalars.filter { scalar in
            if scalar.properties.isDefaultIgnorableCodePoint { return false }
            if scalar.value < 0x20 || scalar.value == 0x7F { return false }
            return true
        }
        let sanitized = String(String.UnicodeScalarView(cleanedScalars))
        let stripped = sanitized
            .replacingOccurrences(of: "^\\s*[\"']", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\"']\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = stripped.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? stripped
        return String(firstLine.prefix(180))
    }
}
