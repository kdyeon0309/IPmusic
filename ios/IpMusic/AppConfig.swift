import Foundation

/// 개발용 앱 설정. 인증은 M3 범위 — M1에서는 내가 alice로 고정이다.
enum AppConfig {
    /// 내 사용자 ID (백엔드 seed의 alice와 짝).
    static let userId = "alice"

    /// 내 캐릭터 이모지.
    static let characterEmoji = "🐰"

    #if targetEnvironment(simulator)
    /// 시뮬레이터는 Mac과 같은 호스트라 localhost로 백엔드에 닿는다.
    static let serverHost = "localhost:8000"
    #else
    /// 실기기는 localhost가 기기 자신을 가리키므로 Mac의 LAN IP가 필요하다.
    /// (Mac에서 `ipconfig getifaddr en0`로 확인 — 네트워크가 바뀌면 갱신할 것)
    static let serverHost = "192.168.219.119:8000"
    #endif

    /// presence WebSocket 주소.
    static var wsURL: URL {
        URL(string: "ws://\(serverHost)/ws?user_id=\(userId)")!
    }
}
