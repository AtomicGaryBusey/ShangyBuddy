# Shangy

A native macOS desktop pal in the spirit of Bonzi Buddy, except deeply unhelpful.

A 3D-modeled digital soothsayer paces back and forth across the bottom of your
screen, gesturing like he's giving an endless TED talk, occasionally pausing to
deliver a short, off-the-wall prophecy about whatever you're doing — generated
locally by Ollama from periodic screen captures. Nothing leaves your machine.

## Status

This repo is a working scaffold. It builds, runs, paces, and talks. Animations,
walk cycle, screen capture, Ollama vision integration, and the floating window
are all wired up. The character is drawn procedurally in SceneKit (no
copyrighted likeness), so swap in better art whenever you want.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9 toolchain (Xcode 15+ or `swift` CLI)
- [Ollama](https://ollama.com) running locally with a vision model pulled:

  ```bash
  ollama pull llama3.2-vision
  ```

  The default endpoint is `http://127.0.0.1:11434` and the default model is
  `llama3.2-vision`. Override by editing `OllamaClient.swift` if you want to
  try a different vision model (e.g. `llava`, `qwen2.5vl`, etc).

## Build & run

```bash
./build.sh
open dist/Shangy.app
```

`build.sh` produces a proper `.app` bundle under `dist/`, ad-hoc codesigns it
(required for ScreenCaptureKit permissions to stick), and prints the launch
command.

On first launch, macOS prompts for **Screen Recording**. Approve it in
*System Settings → Privacy & Security → Screen Recording*, then relaunch.

> ⚠️ **Rebuilds revoke Screen Recording silently.** TCC keys the permission
> to the binary's ad-hoc code-signature hash, which changes every time you
> `./build.sh`. After a rebuild, Shangy will silently fall back to its blind
> offline prophecies. To re-enable: open *System Settings → Privacy &
> Security → Screen Recording*, remove the old `Shangy` entry, then toggle
> the new one back on (or just toggle the existing entry off + on). For a
> stable hash across rebuilds, sign with a real Developer ID instead of
> ad-hoc.

## What it does

- Floating, click-through window that spans the bottom of the primary display
  and joins all spaces.
- A 3D rigged character (head, big hair, robe, arms, legs, glowing forehead
  gem) with a walk cycle, idle sway, and a periodic "raise hand to address the
  audience" gesture.
- Every ~30–75 seconds, captures a downscaled JPEG of the primary display,
  POSTs it to Ollama with a system prompt that locks the model into a cryptic,
  unhelpful, oracular persona, and floats the response above the character in a
  speech bubble.
- Menu-bar item with **Speak Now**, **Toggle Visibility**, **Settings…** (opens
  the Privacy pane), and **Quit**.

## Files

```
Sources/Shangy/
  main.swift                       app entry
  App/AppDelegate.swift             panel + menu bar setup, screen reflow
  Windows/FloatingPanel.swift       borderless, all-spaces, click-through panel
  Scene3D/SoothsayerScene.swift     SceneKit scene, lighting, camera
  Scene3D/SoothsayerRig.swift       procedural 3D character rig
  Scene3D/WalkCycle.swift           pace / pause / gesture state machine
  Views/SceneHostView.swift         NSViewRepresentable wrapper for SCNView
  Views/SoothsayerView.swift        SwiftUI root view + bubble follow
  Views/SpeechBubbleView.swift      bubble shape + styling
  Capture/ScreenCapturer.swift      ScreenCaptureKit JPEG snapshotter
  Ollama/OllamaClient.swift         /api/chat client with image attachments
  Brain/Persona.swift               system prompt + fallback prophecies
  Brain/ShangyBrain.swift           timer loop, scene owner, bubble state
  Resources/Info.plist              bundle plist (ScreenCapture usage etc.)
```

## Tuning

- **How often he talks** — `produceProphecy` schedule in `ShangyBrain.swift`
  (currently 35–75 s).
- **Pacing speed and bounds** — `WalkCycle.swift` (`speed`, `setStageWidth`).
- **Persona** — `Brain/Persona.swift`.
- **Vision model** — `OllamaConfig` in `Ollama/OllamaClient.swift`.
- **Character design** — everything in `Scene3D/SoothsayerRig.swift` is
  primitives; tweak materials, scales, and limb anchors freely. Swap the
  procedural rig for a `.scn` / `.usdz` asset when you want fancier art.

## Notes

- Self-contained: the only network call goes to `127.0.0.1:11434`. Screenshots
  never leave the machine. The Ollama client refuses to send to any host that
  isn't `127.0.0.1`, `::1`, or `localhost` (hard-coded loopback guard), uses an
  ephemeral `URLSession` with no on-disk cache, and the screenshot `Data` is
  scoped tightly so it's released the moment the request completes — it does
  not outlive the visible speech bubble.
- Click-through: the panel ignores mouse events so it doesn't steal clicks
  while pacing across your work. Use the menu bar item to interact.
