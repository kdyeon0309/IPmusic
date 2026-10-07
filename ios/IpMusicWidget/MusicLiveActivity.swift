import ActivityKit
import SwiftUI
import WidgetKit

/// 음악 감상 상태를 다이나믹 아일랜드와 잠금 화면에 보여주는 Live Activity.
///
/// M1 범위: 본인 캐릭터 + 트랙에 더해, 음악을 듣는 친구가 등장한다.
/// 접힌 노치(compact)에서도 친구 이모지가 보이는 것이 M1의 핵심 감성.
struct MusicLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.characterEmoji)
                        .font(.system(size: 44))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PlayingIndicator(isPlaying: context.state.isPlaying)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(
                        isPlaying: context.state.isPlaying,
                        friend: context.state.friends.first
                    )
                }
            } compactLeading: {
                Text(context.attributes.characterEmoji)
            } compactTrailing: {
                // 친구가 음악을 들으면 접힌 노치에도 친구 캐릭터가 등장한다
                if let friend = context.state.friends.first {
                    Text(friend.emoji)
                } else {
                    // 위젯 타깃에 액센트 색 에셋이 없어 .tint는 no-op — 명시적 색 사용
                    PlayingIndicator(isPlaying: context.state.isPlaying)
                        .foregroundStyle(.white)
                }
            } minimal: {
                // 노치가 다른 Live Activity(전화, 애플뮤직 재생 등)와 갈라진 상태에선
                // 이 동그라미 하나가 전부다 — 친구 등장이 핵심 가치이므로 친구를 우선 표시.
                Text(context.state.friends.first?.emoji ?? context.attributes.characterEmoji)
            }
        }
    }
}

/// 잠금 화면 / 알림 배너에 표시되는 뷰.
private struct LockScreenView: View {
    let context: ActivityViewContext<MusicActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(context.attributes.characterEmoji)
                    .font(.system(size: 36))

                VStack(alignment: .leading) {
                    Text(context.state.trackTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                PlayingIndicator(isPlaying: context.state.isPlaying)
                    .font(.title2)
            }

            // 음악 듣는 친구들 (M2) — 잠금화면 카드에서도 보이게
            if !context.state.friends.isEmpty {
                ForEach(context.state.friends, id: \.id) { friend in
                    HStack(spacing: 6) {
                        Text(friend.emoji)
                            .font(.title3)
                        Text("\(friend.trackTitle) — \(friend.artistName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

/// 다이나믹 아일랜드 확장 상태의 가운데 영역(트랙 제목 / 아티스트).
private struct ExpandedCenterView: View {
    let state: MusicActivityAttributes.ContentState

    var body: some View {
        VStack {
            Text(state.trackTitle)
                .font(.headline)
                .lineLimit(1)
            Text(state.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// 다이나믹 아일랜드 확장 상태의 하단 영역.
///
/// 친구가 음악을 듣고 있으면 친구 캐릭터 + 곡 한 줄, 없으면 내 재생 상태 문구.
private struct ExpandedBottomView: View {
    let isPlaying: Bool
    let friend: FriendState?

    var body: some View {
        if let friend {
            HStack(spacing: 6) {
                // M2: 악세사리 오버레이 (expanded에서만 — compact는 좁아 클리핑 위험)
                ZStack {
                    Text(friend.emoji)
                        .font(.title3)
                    if let accessory = CharacterAccessory(rawValue: friend.accessory ?? ""),
                       let overlay = accessory.overlayEmoji {
                        Text(overlay)
                            .font(.system(size: 10))
                            .offset(
                                x: 22 * accessory.offsetRatio.width,
                                y: 22 * accessory.offsetRatio.height
                            )
                    }
                }
                Text("\(friend.trackTitle) — \(friend.artistName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !friend.isPlaying {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text(isPlaying ? "듣는 중" : "일시정지")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// 재생/일시정지 상태를 나타내는 SF Symbol.
private struct PlayingIndicator: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: isPlaying ? "music.note" : "pause.fill")
    }
}
