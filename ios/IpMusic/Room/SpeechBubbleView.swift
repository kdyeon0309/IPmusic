import SwiftUI

/// 캐릭터 머리 위 말풍선 — 둥근 사각형 + 아래 꼬리.
struct SpeechBubbleView: View {
    let text: String

    var body: some View {
        VStack(spacing: -1) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 160)
            // 꼬리: 45도 돌린 작은 사각형의 아랫부분만 보이게
            Rectangle()
                .fill(.regularMaterial)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .offset(y: -5)
                .clipped()
        }
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        SpeechBubbleView(text: "안녕!")
        SpeechBubbleView(text: "이 노래 진짜 좋다 들어봐 🎶")
    }
    .padding()
}
