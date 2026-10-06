import SwiftUI

/// WU3 디버그 패널: 목(mock) 데이터로 Live Activity를 구동해 다이나믹 아일랜드 UI를 검증한다.
struct ContentView: View {
    private static let mockTracks: [(title: String, artist: String)] = [
        ("Ditto", "NewJeans"),
        ("Love wins all", "IU"),
        ("Super Shy", "NewJeans"),
        ("밤편지", "아이유")
    ]

    @State private var manager = LiveActivityManager()
    @State private var trackIndex = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("IpMusic")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Live Activity 데모 (WU3)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            statusSection

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
                .disabled(!manager.isSessionActive)

                Button("종료") {
                    Task {
                        await manager.end()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!manager.isSessionActive)
            }
        }
        .padding()
        .task {
            await manager.endOrphanedActivities()
            // 설정 앱에서 Live Activity 허용을 바꾸고 돌아온 경우를 반영 (뷰가 사라지면 자동 취소)
            await manager.observeAuthorizationUpdates()
        }
    }

    private var statusSection: some View {
        VStack(spacing: 6) {
            Text(manager.isSessionActive ? "세션 활성 — 노치를 확인하세요" : "세션 없음")
                .font(.headline)
                .foregroundStyle(manager.isSessionActive ? .green : .secondary)

            if !manager.areActivitiesEnabled {
                Text("설정 앱에서 Live Activity를 허용해야 데모를 시작할 수 있습니다.")
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
}

#Preview {
    ContentView()
}
