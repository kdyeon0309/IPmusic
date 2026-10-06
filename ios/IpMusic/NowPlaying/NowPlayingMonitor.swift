import MediaPlayer
import Observation

/// 애플뮤직(시스템 음악 플레이어)의 now-playing 상태를 감지하는 모니터.
///
/// WU4 범위: `MPMusicPlayerController.systemMusicPlayer`의 시스템 알림을 구독해
/// 현재 트랙과 재생 여부를 노출한다. 애플뮤직 앱에서 재생 중인 곡만 감지된다
/// (iOS는 Spotify 등 서드파티 앱의 로컬 감지가 불가능 — BRIEF 5번 참고).
@MainActor
@Observable
final class NowPlayingMonitor {
    /// 감지된 트랙 정보. Equatable이어야 SwiftUI `.onChange`로 변화를 감지할 수 있다.
    struct Track: Equatable {
        var title: String
        var artist: String
    }

    /// 현재 재생(또는 일시정지) 중인 트랙. 애플뮤직에 재생 큐가 없으면 nil.
    private(set) var currentTrack: Track?

    /// 실제로 재생 중이면 true (일시정지/정지는 false).
    private(set) var isPlaying = false

    /// 미디어 라이브러리 접근 권한 상태. nowPlayingItem을 읽으려면 .authorized여야 한다.
    private(set) var authorizationStatus = MPMediaLibrary.authorizationStatus()

    /// 시스템 전역 음악 플레이어의 거울. 우리 앱이 재생하지 않아도 애플뮤직 앱 상태를 읽는다.
    private let player = MPMusicPlayerController.systemMusicPlayer

    /// 구독 중인 시스템 알림 토큰. 비어있지 않으면 감지 중이라는 뜻.
    private var observers: [NSObjectProtocol] = []

    /// strict concurrency 모드에서도 @State 기본값 위치에서 생성 가능하도록 nonisolated로 선언.
    nonisolated init() {}

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var isMonitoring: Bool {
        !observers.isEmpty
    }

    /// 미디어 라이브러리 접근 권한을 요청한다 (최초 1회만 시스템 다이얼로그가 뜸).
    func requestAuthorizationIfNeeded() async {
        guard authorizationStatus == .notDetermined else { return }
        authorizationStatus = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// 재생 상태 알림 구독을 시작하고, 현재 상태를 즉시 한 번 읽는다.
    func start() {
        guard observers.isEmpty else { return }

        // 이 호출이 있어야 아래 두 알림이 발송되기 시작한다.
        player.beginGeneratingPlaybackNotifications()

        let names: [Notification.Name] = [
            .MPMusicPlayerControllerNowPlayingItemDidChange,
            .MPMusicPlayerControllerPlaybackStateDidChange
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name, object: player, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }

        refresh()
    }

    /// 알림 구독을 해제하고 감지 상태를 초기화한다.
    func stop() {
        guard !observers.isEmpty else { return }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        player.endGeneratingPlaybackNotifications()
        currentTrack = nil
        isPlaying = false
    }

    /// 플레이어에서 현재 트랙/재생 여부를 다시 읽는다.
    private func refresh() {
        isPlaying = player.playbackState == .playing

        if let item = player.nowPlayingItem {
            currentTrack = Track(
                title: item.title ?? "알 수 없는 곡",
                artist: item.artist ?? "알 수 없는 아티스트"
            )
        } else {
            currentTrack = nil
        }
    }
}
