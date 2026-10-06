import ActivityKit
import SwiftUI
import WidgetKit

/// 친구의 음악 감상 상태를 다이나믹 아일랜드와 잠금 화면에 보여주는 Live Activity.
///
/// M0 범위: 본인 캐릭터(이모지)와 현재 트랙 정보만 표시한다.
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
                    ExpandedBottomView(isPlaying: context.state.isPlaying)
                }
            } compactLeading: {
                Text(context.attributes.characterEmoji)
            } compactTrailing: {
                // 위젯 타깃에 액센트 색 에셋이 없어 .tint는 no-op — 명시적 색 사용
                PlayingIndicator(isPlaying: context.state.isPlaying)
                    .foregroundStyle(.white)
            } minimal: {
                Text(context.attributes.characterEmoji)
            }
        }
    }
}

/// 잠금 화면 / 알림 배너에 표시되는 뷰.
private struct LockScreenView: View {
    let context: ActivityViewContext<MusicActivityAttributes>

    var body: some View {
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

/// 다이나믹 아일랜드 확장 상태의 하단 영역(재생 상태 문구).
private struct ExpandedBottomView: View {
    let isPlaying: Bool

    var body: some View {
        HStack {
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
