import ActivityKit
import Foundation

/// 앱과 위젯 확장이 공유하는 Live Activity 계약(Contract).
///
/// M1 범위: 내 캐릭터 + 트랙에 더해, 지금 음악을 듣는 친구들(`friends`)을 표현한다.
/// ⚠️ ContentState를 바꾸면 앱과 위젯을 **동시에 재빌드**해야 한다 (Codable 불일치 시 갱신 실패).
struct MusicActivityAttributes: ActivityAttributes {
    /// 재생 상태가 바뀔 때마다 갱신되는 값. 페이로드 4KB 제한 — friends는 최대 3명.
    struct ContentState: Codable, Hashable {
        /// 현재 재생 중인 트랙 제목.
        var trackTitle: String
        /// 아티스트 이름.
        var artistName: String
        /// 재생 중이면 true, 일시정지면 false.
        var isPlaying: Bool
        /// 마지막으로 상태가 변경된 시각.
        var changedAt: Date
        /// 지금 음악을 듣고 있는 친구들 (M1: UI는 첫 친구만 크게 표시).
        var friends: [FriendState] = []
    }

    /// 세션 동안 고정되는 내 캐릭터 (M0: 이모지 플레이스홀더)
    var characterEmoji: String
}
