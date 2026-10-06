import SwiftUI

/// 방 테마 프리셋 — 벽(상단 그라데이션)·바닥·포인트 색.
/// 코드(rawValue)만 서버에 저장되고 색 해석은 클라이언트가 한다.
/// 테마는 "내 방"에만 적용되므로 친구에게 전송되지 않는다 (ContentState 4KB 보호).
enum RoomTheme: String, CaseIterable, Identifiable {
    case cream
    case mint
    case lavender
    case night
    case peach

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cream: "크림"
        case .mint: "민트"
        case .lavender: "라벤더"
        case .night: "밤하늘"
        case .peach: "피치"
        }
    }

    /// 벽 그라데이션 (위 → 아래).
    var wallColors: [Color] {
        switch self {
        case .cream:
            [Color(red: 1.0, green: 0.97, blue: 0.9), Color(red: 0.98, green: 0.9, blue: 0.82)]
        case .mint:
            [Color(red: 0.88, green: 0.98, blue: 0.94), Color(red: 0.76, green: 0.93, blue: 0.86)]
        case .lavender:
            [Color(red: 0.95, green: 0.92, blue: 1.0), Color(red: 0.86, green: 0.8, blue: 0.96)]
        case .night:
            [Color(red: 0.13, green: 0.15, blue: 0.3), Color(red: 0.07, green: 0.08, blue: 0.18)]
        case .peach:
            [Color(red: 1.0, green: 0.93, blue: 0.89), Color(red: 1.0, green: 0.84, blue: 0.76)]
        }
    }

    /// 바닥 색.
    var floorColor: Color {
        switch self {
        case .cream: Color(red: 0.93, green: 0.84, blue: 0.72)
        case .mint: Color(red: 0.62, green: 0.84, blue: 0.76)
        case .lavender: Color(red: 0.74, green: 0.68, blue: 0.88)
        case .night: Color(red: 0.2, green: 0.22, blue: 0.38)
        case .peach: Color(red: 0.95, green: 0.74, blue: 0.64)
        }
    }

    /// 어두운 테마인지 — 텍스트 대비용.
    var isDark: Bool { self == .night }
}
