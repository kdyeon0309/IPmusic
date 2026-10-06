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
    /// 애플뮤직 카탈로그 ID (M2). 없으면 "" — 서버 기본값과 동일.
    var storeId = ""
    var ts = PresenceMessage.nowISO8601()
}

/// 클라이언트 → 서버: 세션 종료/백그라운드 진입 보고.
struct StoppedReport: Encodable {
    var type = "stopped"
    var ts = PresenceMessage.nowISO8601()
}

/// 클라이언트 → 서버: 내 캐릭터 꾸미기 변경 (M2).
struct SetCustomizationMessage: Encodable {
    var type = "set_customization"
    var accessory: String
    var roomTheme: String
    var ts = PresenceMessage.nowISO8601()
}

/// 클라이언트 → 서버: 말풍선 전송 (M2, 최대 50자 — 초과 시 서버가 무시).
struct BubbleSendMessage: Encodable {
    var type = "bubble"
    var to: String
    var text: String
    var ts = PresenceMessage.nowISO8601()
}

/// 서버 → 클라이언트: 친구 말풍선 push (M2).
struct FriendBubblePush: Decodable {
    var type: String
    var fromId: String
    var fromEmoji: String
    var text: String
    var ts: String
}

/// 클라이언트 → 서버: 곡 추천 전송 (M2, 영속 — 오프라인 친구도 다음 접속 시 수신).
struct RecommendSendMessage: Encodable {
    var type = "recommend"
    var to: String
    var track: String
    var artist: String
    var storeId: String
    var ts = PresenceMessage.nowISO8601()
}

/// 클라이언트 → 서버: 추천 확인 — 이후 재전달되지 않는다.
struct RecommendationAckMessage: Encodable {
    var type = "recommendation_ack"
    var recommendationId: Int
    var ts = PresenceMessage.nowISO8601()
}

/// 서버 → 클라이언트: 친구 곡 추천 push (M2). 접속 시 pending도 이 형태로 온다.
struct FriendRecommendationPush: Decodable {
    var type: String
    var id: Int
    var fromId: String
    var fromEmoji: String
    var track: String
    var artist: String
    var storeId: String
    var ts: String
}

/// 서버 → 클라이언트: 친구 presence push.
struct FriendPresencePush: Decodable {
    var type: String
    /// "playing"(등장·곡 변경) 또는 "stopped"(퇴장).
    var event: String
    var friendId: String
    var emoji: String
    /// 악세사리 코드 (M2). 구버전 서버 페이로드엔 없을 수 있어 옵셔널.
    var accessory: String?
    var track: String
    var artist: String
    var isPlaying: Bool
    var ts: String
}
