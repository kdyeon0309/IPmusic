import SwiftUI

/// M1 메인 화면: 내 애플뮤직 now-playing을 감지해 서버에 자가보고하고,
/// 친구의 presence를 받아 Live Activity(노치)에 함께 표시한다.
///
/// - 실제 세션: NowPlayingMonitor가 감지한 곡 → Live Activity + PresenceService(서버 보고).
///   친구 상태는 PresenceService.friends로 들어와 노치/화면에 반영된다. 실기기 전용.
/// - 목 데모: 가짜 곡/친구 데이터로 노치 UI만 검증. 시뮬레이터에서 사용.
struct ContentView: View {
    private static let mockTracks: [(title: String, artist: String)] = [
        ("Ditto", "NewJeans"),
        ("Love wins all", "IU"),
        ("Super Shy", "NewJeans"),
        ("밤편지", "아이유")
    ]

    @Environment(\.scenePhase) private var scenePhase

    @State private var manager = LiveActivityManager()
    @State private var monitor = NowPlayingMonitor()
    @State private var presence = PresenceService()
    @State private var trackIndex = 0

    /// 현재 Live Activity가 실제 감지 세션인지(목 데모가 아니라) 여부.
    @State private var isRealSession = false

    /// 목 데모에서 가짜 친구가 등장해 있는지 여부.
    @State private var mockFriendVisible = false

    var body: some View {
        VStack(spacing: 16) {
            Text("IpMusic")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("노치에 친구가 산다 (M1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            statusSection
            nowPlayingSection
            friendsSection
            realSessionControls
            mockDemoSection
        }
        .padding()
        .task {
            await manager.endOrphanedActivities()
            // 설정 앱에서 Live Activity 허용을 바꾸고 돌아온 경우를 반영 (뷰가 사라지면 자동 취소)
            await manager.observeAuthorizationUpdates()
        }
        // 감지된 곡/재생 상태가 바뀔 때마다 서버 보고 + Live Activity에 반영
        .onChange(of: monitor.currentTrack) { syncActivityWithMonitor() }
        .onChange(of: monitor.isPlaying) { syncActivityWithMonitor() }
        // 친구 presence가 바뀌면(등장/곡 변경/퇴장) Live Activity에 반영
        .onChange(of: presence.friends) { syncFriendsToActivity() }
        // 사용자가 잠금화면에서 스와이프로 지우는 등 세션이 밖에서 끝난 경우 정리
        .onChange(of: manager.isSessionActive) { _, isActive in
            if !isActive && isRealSession {
                isRealSession = false
                monitor.stop()
                Task { await presence.disconnect(clearFriends: true) }
            }
        }
        // 포그라운드 복귀 시 재연결, 백그라운드 진입 시 stopped 보고 후 연결 종료
        // (무료 계정 = APNs 불가 → 앱이 살아있는 동안만 동작. BRIEF 5번)
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
    }

    // MARK: - 실제 감지 세션 (WU4)

    private var nowPlayingSection: some View {
        VStack(spacing: 4) {
            if let track = monitor.currentTrack {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(monitor.isPlaying ? "재생 중" : "일시정지")
                    .font(.caption)
                    .foregroundStyle(monitor.isPlaying ? .green : .secondary)
            } else if monitor.isMonitoring {
                Text("애플뮤직에서 음악을 재생하면 여기에 표시됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var realSessionControls: some View {
        VStack(spacing: 12) {
            Button("내 음악 세션 시작") {
                Task {
                    await startRealSession()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.isSessionActive)

            Button("세션 종료") {
                Task {
                    await endRealSession()
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!isRealSession)

            if monitor.authorizationStatus == .denied || monitor.authorizationStatus == .restricted {
                Text("설정 앱에서 미디어 라이브러리 접근을 허용해야 재생 중인 곡을 읽을 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func startRealSession() async {
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

    private func endRealSession() async {
        isRealSession = false
        monitor.stop()
        await presence.disconnect(clearFriends: true)
        await manager.end()
    }

    /// 감지 상태를 서버에 보고하고 Live Activity에 반영한다. 목 데모 세션은 건드리지 않는다.
    private func syncActivityWithMonitor() {
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
    private func syncFriendsToActivity() {
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

    private func handleScenePhase(_ phase: ScenePhase) {
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

    // MARK: - 친구 presence (M1)

    private var friendsSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("친구")
                    .font(.headline)
                Circle()
                    .fill(presence.isConnected ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(presence.isConnected ? "서버 연결됨" : "오프라인")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if presence.friends.isEmpty {
                Text("지금 음악을 듣는 친구가 없어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presence.friends) { friend in
                    HStack(spacing: 8) {
                        Text(friend.emoji)
                            .font(.title3)
                        VStack(alignment: .leading) {
                            Text(friend.trackTitle)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(friend.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: friend.isPlaying ? "music.note" : "pause.fill")
                            .font(.caption)
                            .foregroundStyle(friend.isPlaying ? .green : .secondary)
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 상태 표시

    private var statusSection: some View {
        VStack(spacing: 6) {
            Text(manager.isSessionActive ? "세션 활성 — 노치를 확인하세요" : "세션 없음")
                .font(.headline)
                .foregroundStyle(manager.isSessionActive ? .green : .secondary)

            if !manager.areActivitiesEnabled {
                Text("설정 앱에서 Live Activity를 허용해야 세션을 시작할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if let err = manager.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 목 데모 (WU3, 시뮬레이터용)

    private var mockDemoSection: some View {
        DisclosureGroup("목 데모 (시뮬레이터용)") {
            VStack(spacing: 12) {
                Button("데모 시작") {
                    trackIndex = 0
                    let track = Self.mockTracks[trackIndex]
                    manager.start(characterEmoji: "🐰", title: track.title, artist: track.artist)
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isSessionActive)

                Button("다음 곡 (목)") {
                    trackIndex = (trackIndex + 1) % Self.mockTracks.count
                    let track = Self.mockTracks[trackIndex]
                    Task {
                        await manager.update(title: track.title, artist: track.artist, isPlaying: true)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!manager.isSessionActive || isRealSession)

                Button(mockFriendVisible ? "친구 퇴장 (목)" : "친구 등장 (목)") {
                    mockFriendVisible.toggle()
                    let friends = mockFriendVisible
                        ? [FriendState(id: "bob", emoji: "🐸", trackTitle: "밤편지",
                                       artistName: "아이유", isPlaying: true)]
                        : []
                    let track = Self.mockTracks[trackIndex]
                    Task {
                        await manager.update(
                            title: track.title, artist: track.artist,
                            isPlaying: true, friends: friends
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!manager.isSessionActive || isRealSession)

                Button("종료") {
                    Task {
                        await manager.end()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!manager.isSessionActive || isRealSession)
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
    }
}

#Preview {
    ContentView()
}
