import SwiftUI

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .serif))
            .italic()
            .foregroundColor(.black.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 260)
            .background(
                BubbleShape()
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .purple.opacity(0.4), radius: 6)
            )
            .overlay(
                BubbleShape()
                    .stroke(Color.purple.opacity(0.4), lineWidth: 1)
            )
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                )
            )
    }
}

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 14
        let tail: CGFloat = 12
        let body = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tail
        )
        p.addRoundedRect(in: body, cornerSize: CGSize(width: r, height: r))
        p.move(to: CGPoint(x: rect.midX - 10, y: body.maxY))
        p.addLine(to: CGPoint(x: rect.midX + 4, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX + 8, y: body.maxY))
        p.closeSubpath()
        return p
    }
}
