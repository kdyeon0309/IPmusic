import Foundation

/// 공간/노치에 표시할 친구 1명의 presence 상태.
///
/// Live Activity ContentState에 들어가므로 앱과 위젯이 공유한다 (Shared/).
struct FriendState: Codable, Hashable, Identifiable {
    /// 친구의 사용자 ID.
    var id: String
    /// 친구 캐릭터 이모지.
    var emoji: String
    /// 악세사리 프리셋 코드 (CharacterAccessory.rawValue). 옵셔널이라
    /// 키가 없는 구(M1) 페이로드도 디코딩에 성공한다 — Codable silent failure 방지.
    var accessory: String? = nil
    /// 친구가 듣고 있는 트랙 제목.
    var trackTitle: String
    /// 아티스트 이름.
    var artistName: String
    /// 재생 중이면 true, 일시정지면 false.
    var isPlaying: Bool
}
