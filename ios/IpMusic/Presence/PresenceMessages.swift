import Foundation

/// 백엔드 WS 프로토콜의 Swift 미러 (backend/app/schemas.py와 짝).
///
/// JSON 키는 서버가 snake_case라서 인코더/디코더에 keyStrategy를 설정해 변환한다.
/// `ts`는 클라이언트에서 쓰지 않으므로 Date 파싱 없이 ISO8601 문자열 그대로 다룬다.
enum PresenceMessage {
    /// 공용 인코더 (camelCase → snake_case).
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    /// 공용 디코더 (snake_case → camelCase).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func nowISO8601() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

/// 클라이언트 → 서버: 내 now-playing 자가보고.
struct NowPlayingReport: Encodable {
    var type = "now_playing"
    var track: String
    var artist: String
    var isPlaying: Bool
    var source = "apple_music"
    var ts = PresenceMessage.nowISO8601()
}

/// 클라이언트 → 서버: 세션 종료/백그라운드 진입 보고.
struct StoppedReport: Encodable {
    var type = "stopped"
    var ts = PresenceMessage.nowISO8601()
}

/// 서버 → 클라이언트: 친구 presence push.
struct FriendPresencePush: Decodable {
    var type: String
    /// "playing"(등장·곡 변경) 또는 "stopped"(퇴장).
    var event: String
    var friendId: String
    var emoji: String
    var track: String
    var artist: String
    var isPlaying: Bool
    var ts: String
}
