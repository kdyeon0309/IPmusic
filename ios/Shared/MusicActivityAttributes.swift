import ActivityKit
import Foundation

/// 앱과 위젯 확장이 공유하는 Live Activity 계약(Contract).
///
/// M0 범위: 사용자 본인의 캐릭터(이모지 플레이스홀더)와 현재 재생 트랙 정보만 표현한다.
struct MusicActivityAttributes: ActivityAttributes {
    /// 재생 상태가 바뀔 때마다 갱신되는 값.
    struct ContentState: Codable, Hashable {
        /// 현재 재생 중인 트랙 제목.
        var trackTitle: String
        /// 아티스트 이름.
        var artistName: String
        /// 재생 중이면 true, 일시정지면 false.
        var isPlaying: Bool
        /// 마지막으로 상태가 변경된 시각.
        var changedAt: Date
    }

    /// 세션 동안 고정되는 내 캐릭터 (M0: 이모지 플레이스홀더)
    var characterEmoji: String
}
