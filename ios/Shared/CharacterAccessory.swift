import CoreGraphics
import Foundation

/// 캐릭터 악세사리 프리셋 카탈로그.
///
/// 서버/프로토콜에는 rawValue 코드 문자열만 흐르고, 코드 → 이모지/위치 매핑은
/// 클라이언트(여기)가 가진다 — 나중에 이미지 에셋으로 바꿔도 프로토콜은 그대로.
/// 위젯(노치)도 렌더링하므로 Shared/에 둔다.
enum CharacterAccessory: String, CaseIterable, Identifiable {
    case none = ""
    case ribbon
    case cap
    case glasses
    case crown
    case headphones

    var id: String { rawValue }

    /// 캐릭터 본체 위에 겹칠 이모지. none이면 nil.
    var overlayEmoji: String? {
        switch self {
        case .none: nil
        case .ribbon: "🎀"
        case .cap: "🧢"
        case .glasses: "🕶️"
        case .crown: "👑"
        case .headphones: "🎧"
        }
    }

    /// 본체 크기 대비 오버레이 위치 비율 (x: 좌우, y: 상하 — 음수가 위).
    /// CharacterView가 본체 폰트 크기에 곱해 offset으로 쓴다.
    var offsetRatio: CGSize {
        switch self {
        case .none: .zero
        case .ribbon: CGSize(width: 0.28, height: -0.38)   // 머리 오른쪽 위
        case .cap: CGSize(width: 0, height: -0.42)          // 정수리
        case .glasses: CGSize(width: 0, height: -0.08)      // 눈 위치
        case .crown: CGSize(width: 0, height: -0.48)        // 정수리 위
        case .headphones: CGSize(width: 0, height: -0.18)   // 귀 위치
        }
    }

    /// 꾸미기 피커에 표시할 이름.
    var displayName: String {
        switch self {
        case .none: "없음"
        case .ribbon: "리본"
        case .cap: "모자"
        case .glasses: "선글라스"
        case .crown: "왕관"
        case .headphones: "헤드폰"
        }
    }
}
