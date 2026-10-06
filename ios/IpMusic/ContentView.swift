import SwiftUI

/// M0 메인 화면: 애플뮤직 now-playing을 감지해 Live Activity로 노치에 표시한다.
///
/// - 실제 세션 (WU4): NowPlayingMonitor가 감지한 곡을 Live Activity에 연결. 실기기 전용
///   (시뮬레이터에는 애플뮤직 앱이 없음).
/// - 목 데모 (WU3): 가짜 곡 데이터로 노치 UI만 검증. 시뮬레이터에서 사용.
struct ContentView: View {
    private static let mockTracks: [(title: String, artist: String)] = [
        ("Ditto", "NewJeans"),
        ("Love wins all", "IU"),
        ("Super Shy", "NewJeans"),
        ("밤편지", "아이유")
    ]

    @State private var manager = LiveActivityManager()
    @State private var monitor = NowPlayingMonitor()
    @State private var trackIndex = 0

    /// 현재 Live Activity가 실제 감지 세션인지(목 데모가 아니라) 여부.
    @State private var isRealSession = false

    var body: some View {
        VStack(spacing: 16) {
            Text("IpMusic")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("내 음악이 노치에 산다 (M0)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            statusSection
            nowPlayingSection
            realSessionControls
            mockDemoSection
        }
        .padding()
        .task {
            await manager.endOrphanedActivities()
            // 설정 앱에서 Live Activity 허용을 바꾸고 돌아온 경우를 반영 (뷰가 사라지면 자동 취소)
            await manager.observeAuthorizationUpdates()
        }
        // 감지된 곡/재생 상태가 바뀔 때마다 Live Activity에 반영
        .onChange(of: monitor.currentTrack) { syncActivityWithMonitor() }
        .onChange(of: monitor.isPlaying) { syncActivityWithMonitor() }
        // 사용자가 잠금화면에서 스와이프로 지우는 등 세션이 밖에서 끝난 경우 정리
        .onChange(of: manager.isSessionActive) { _, isActive in
            if !isActive && isRealSession {
                isRealSession = false
                monitor.stop()
            }
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
            characterEmoji: "🐰",
            title: monitor.currentTrack?.title ?? "재생 중인 곡 없음",
            artist: monitor.currentTrack?.artist ?? "애플뮤직에서 재생을 시작하세요"
        )
        isRealSession = manager.isSessionActive
        if !isRealSession {
            monitor.stop()
        }
    }

    private func endRealSession() async {
        isRealSession = false
        monitor.stop()
        await manager.end()
    }

    /// 감지 상태를 Live Activity에 반영한다. 목 데모 세션은 건드리지 않는다.
    private func syncActivityWithMonitor() {
        guard isRealSession, manager.isSessionActive else { return }
        Task {
            if let track = monitor.currentTrack {
                await manager.update(
                    title: track.title,
                    artist: track.artist,
                    isPlaying: monitor.isPlaying
                )
            } else {
                // 재생 큐가 사라짐(앱 종료 등) — 세션은 유지하되 일시정지 상태로 표시
                await manager.update(
                    title: "재생 중인 곡 없음",
                    artist: "애플뮤직에서 재생을 시작하세요",
                    isPlaying: false
                )
            }
        }
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
