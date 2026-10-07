import SwiftUI

/// 디버그 패널 — M1의 ContentView 디버그 UI를 그대로 이식한 시트.
/// 상태 표시·내 재생 정보·친구 리스트·세션 제어·목 데모(시뮬레이터용)를 담는다.
struct DebugPanelView: View {
    private static let mockTracks: [(title: String, artist: String)] = [
        ("Ditto", "NewJeans"),
        ("Love wins all", "IU"),
        ("Super Shy", "NewJeans"),
        ("밤편지", "아이유")
    ]

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var trackIndex = 0
    /// 목 데모에서 가짜 친구가 등장해 있는지 여부.
    @State private var mockFriendVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusSection
                    nowPlayingSection
                    friendsSection
                    realSessionControls
                    mockDemoSection
                }
                .padding()
            }
            .navigationTitle("디버그")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: - 상태 표시

    private var statusSection: some View {
        VStack(spacing: 6) {
            Text(app.manager.isSessionActive ? "세션 활성 — 노치를 확인하세요" : "세션 없음")
                .font(.headline)
                .foregroundStyle(app.manager.isSessionActive ? .green : .secondary)

            if !app.manager.areActivitiesEnabled {
                Text("설정 앱에서 Live Activity를 허용해야 세션을 시작할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if let err = app.manager.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // 백그라운드 keep-alive 상태 (M2 임시 — 출시 전 APNs로 교체 예정)
            HStack(spacing: 6) {
                Circle()
                    .fill(app.keepAlive.isActive ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(app.keepAlive.isActive ? "백그라운드 유지 중 (무음 오디오)" : "백그라운드 유지 꺼짐")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let err = app.keepAlive.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 내 재생 정보

    private var nowPlayingSection: some View {
        VStack(spacing: 4) {
            if let track = app.monitor.currentTrack {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(app.monitor.isPlaying ? "재생 중" : "일시정지")
                    .font(.caption)
                    .foregroundStyle(app.monitor.isPlaying ? .green : .secondary)
            } else if app.monitor.isMonitoring {
                Text("애플뮤직에서 음악을 재생하면 여기에 표시됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("세션을 시작하면 재생 정보가 표시됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 친구 presence

    private var friendsSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("친구")
                    .font(.headline)
                Circle()
                    .fill(app.presence.isConnected ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(app.presence.isConnected ? "서버 연결됨" : "오프라인")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if app.presence.friends.isEmpty {
                Text("지금 음악을 듣는 친구가 없어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(app.presence.friends) { friend in
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

    // MARK: - 세션 제어

    private var realSessionControls: some View {
        VStack(spacing: 12) {
            Button("내 음악 세션 시작") {
                Task { await app.startSession() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(app.manager.isSessionActive)

            Button("세션 종료") {
                Task { await app.endSession() }
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(!app.isRealSession)

            if app.monitor.authorizationStatus == .denied || app.monitor.authorizationStatus == .restricted {
                Text("설정 앱에서 미디어 라이브러리 접근을 허용해야 재생 중인 곡을 읽을 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 목 데모 (시뮬레이터용)

    private var mockDemoSection: some View {
        DisclosureGroup("목 데모 (시뮬레이터용)") {
            VStack(spacing: 12) {
                Button("데모 시작") {
                    trackIndex = 0
                    let track = Self.mockTracks[trackIndex]
                    app.manager.start(characterEmoji: "🐰", title: track.title, artist: track.artist)
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.manager.isSessionActive)

                Button("다음 곡 (목)") {
                    trackIndex = (trackIndex + 1) % Self.mockTracks.count
                    let track = Self.mockTracks[trackIndex]
                    Task {
                        await app.manager.update(title: track.title, artist: track.artist, isPlaying: true)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!app.manager.isSessionActive || app.isRealSession)

                Button(mockFriendVisible ? "친구 퇴장 (목)" : "친구 등장 (목)") {
                    mockFriendVisible.toggle()
                    let friends: [FriendState] = mockFriendVisible
                        ? [FriendState(id: "bob", emoji: "🐸", trackTitle: "밤편지",
                                       artistName: "아이유", isPlaying: true)]
                        : []
                    app.mockFriends = friends  // 방(RoomView)에도 반영
                    let track = Self.mockTracks[trackIndex]
                    Task {
                        await app.manager.update(
                            title: track.title, artist: track.artist,
                            isPlaying: true, friends: friends
                        )
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!app.manager.isSessionActive || app.isRealSession)

                Button("종료") {
                    mockFriendVisible = false
                    app.mockFriends = []
                    Task { await app.manager.end() }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!app.manager.isSessionActive || app.isRealSession)
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
    }
}

#Preview {
    DebugPanelView()
        .environment(AppModel())
}
