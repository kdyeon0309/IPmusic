import SwiftUI

/// 공간에 서 있는 캐릭터 하나 — 이모지 본체 + 이름 + (있으면) 듣는 곡 캡션.
/// WU2에서 악세사리 오버레이, WU3에서 말풍선 슬롯이 여기에 붙는다.
struct CharacterView: View {
    let emoji: String
    let name: String
    var accessory: CharacterAccessory = .none
    var trackTitle: String? = nil
    var artistName: String? = nil
    var isPlaying: Bool = false
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Text(emoji)
                    .font(.system(size: size))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                if let overlay = accessory.overlayEmoji {
                    Text(overlay)
                        .font(.system(size: size * 0.45))
                        .offset(
                            x: size * accessory.offsetRatio.width,
                            y: size * accessory.offsetRatio.height
                        )
                }
            }

            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if let trackTitle {
                HStack(spacing: 3) {
                    Image(systemName: isPlaying ? "music.note" : "pause.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(isPlaying ? .green : .secondary)
                        .symbolEffect(.bounce, options: .repeat(2), value: trackTitle)
                    VStack(spacing: 0) {
                        Text(trackTitle)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                        if let artistName {
                            Text(artistName)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
            }
        }
        .frame(maxWidth: 110)
    }
}

#Preview {
    HStack(spacing: 24) {
        CharacterView(emoji: "🐰", name: "alice", accessory: .ribbon,
                      trackTitle: "Ditto", artistName: "NewJeans", isPlaying: true)
        CharacterView(emoji: "🐸", name: "bob", accessory: .cap,
                      trackTitle: "밤편지", artistName: "아이유", isPlaying: true, size: 52)
    }
    .padding()
}
