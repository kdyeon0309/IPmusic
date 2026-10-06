import SwiftUI
import Observation

/// 앱 세션의 단일 소유자 — Live Activity·now-playing 감지·presence 서비스를 들고,
/// 그 사이의 반응 로직(보고/갱신/scenePhase)을 전부 메서드로 제공한다.
///
/// 뷰 쪽 규칙: 루트(ContentView)가 `@State`로 한 번 생성해 `.environment(app)`으로 내려보내고,
/// 하위 뷰는 `@Environment(AppModel.self)`로 꺼내 쓴다. `@Observable`이라 뷰 body에서 읽는
/// 프로퍼티가 바뀌면 그 뷰만 자동으로 다시 그려진다 (M1의 PresenceService와 같은 매크로).
/// `.onChange(of:)`는 View 전용 API라서 배선 자체는 ContentView에 남고, 본문은 여기 메서드 호출 한 줄이다.
@MainActor
@Observable
final class AppModel {
    let manager = LiveActivityManager()
    let monitor = NowPlayingMonitor()
    let presence = PresenceService()

    /// 현재 Live Activity가 실제 감지 세션인지(목 데모가 아니라) 여부.
    private(set) var isRealSession = false

    /// 목 데모(시뮬레이터)에서 등장시킨 가짜 친구들. 실제 세션에선 항상 비어 있다.
    var mockFriends: [FriendState] = []

    /// 방(RoomView)에 그릴 친구들 — 실제 presence + 목 데모 친구.
    var roomFriends: [FriendState] { presence.friends + mockFriends }

    nonisolated init() {}

    // MARK: - 세션 시작/종료

    func startSession() async {
        mockFriends = []  // 목 데모 잔상 제거
        await monitor.requestAuthorizationIfNeeded()
        guard monitor.isAuthorized else { return }

        monitor.start()
        manager.start(
            characterEmoji: AppConfig.characterEmoji,
            title: monitor.currentTrack?.title ?? "재생 중인 곡 없음",
            artist: monitor.currentTrack?.artist ?? "애플뮤직에서 재생을 시작하세요"
        )
        isRealSession = manager.isSessionActive
        if isRealSession {
            // 서버 연결 + 현재 곡 첫 보고 (친구 수신도 이 연결로 들어온다)
            presence.connect()
            reportToServer()
        } else {
            monitor.stop()
        }
    }

    func endSession() async {
        isRealSession = false
        monitor.stop()
        await presence.disconnect(clearFriends: true)
        await manager.end()
    }

    /// 사용자가 잠금화면에서 스와이프로 지우는 등 세션이 밖에서 끝난 경우 정리.
    func handleSessionEnded() {
        guard isRealSession else { return }
        isRealSession = false
        monitor.stop()
        Task { await presence.disconnect(clearFriends: true) }
    }

    // MARK: - 동기화

    /// 감지 상태를 서버에 보고하고 Live Activity에 반영한다. 목 데모 세션은 건드리지 않는다.
    func syncActivityWithMonitor() {
        guard isRealSession else { return }
        reportToServer()
        guard manager.isSessionActive else { return }
        Task {
            if let track = monitor.currentTrack {
                await manager.update(
                    title: track.title,
                    artist: track.artist,
                    isPlaying: monitor.isPlaying,
                    friends: presence.friends
                )
            } else {
                // 재생 큐가 사라짐(앱 종료 등) — 세션은 유지하되 일시정지 상태로 표시
                await manager.update(
                    title: "재생 중인 곡 없음",
                    artist: "애플뮤직에서 재생을 시작하세요",
                    isPlaying: false,
                    friends: presence.friends
                )
            }
        }
    }

    /// 친구 presence 변화만 Live Activity에 반영한다 (내 트랙 정보는 직전 값 유지).
    func syncFriendsToActivity() {
        guard isRealSession, manager.isSessionActive else { return }
        let track = monitor.currentTrack
        Task {
            await manager.update(
                title: track?.title ?? "재생 중인 곡 없음",
                artist: track?.artist ?? "애플뮤직에서 재생을 시작하세요",
                isPlaying: track != nil && monitor.isPlaying,
                friends: presence.friends
            )
        }
    }

    /// 현재 감지 상태를 서버에 자가보고한다.
    private func reportToServer() {
        if let track = monitor.currentTrack {
            presence.report(title: track.title, artist: track.artist, isPlaying: monitor.isPlaying)
        } else {
            presence.reportStopped()
        }
    }

    // MARK: - scenePhase

    /// 포그라운드 복귀 시 재연결, 백그라운드 진입 시 stopped 보고 후 연결 종료.
    /// (무료 계정 = APNs 불가 → 앱이 살아있는 동안만 동작. BRIEF 5번)
    func handleScenePhase(_ phase: ScenePhase) {
        guard isRealSession else { return }
        switch phase {
        case .active:
            presence.connect()
            reportToServer()
        case .background:
            // 연결만 닫고 친구 목록은 유지 — 노치(Live Activity)는 백그라운드에도 떠 있다.
            // 복귀 시 connect()의 스냅샷+reconcile이 최신 상태로 맞춘다.
            Task { await presence.disconnect() }
        default:
            break
        }
    }
}
