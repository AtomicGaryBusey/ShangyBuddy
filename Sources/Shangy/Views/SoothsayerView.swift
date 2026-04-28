import SwiftUI

struct SoothsayerView: View {
    @EnvironmentObject var brain: ShangyBrain
    @State private var bubbleX: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                SceneHostView(scene: brain.scene) { normalized in
                    bubbleX = normalized
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let line = brain.currentLine {
                    SpeechBubble(text: line)
                        .id(line)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(
                            x: clampedBubbleX(geo.size.width),
                            y: -geo.size.height + 30
                        )
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: line)
                }
            }
        }
    }

    private func clampedBubbleX(_ width: CGFloat) -> CGFloat {
        let target = bubbleX * width - 130
        return min(max(target, 8), width - 268)
    }
}
