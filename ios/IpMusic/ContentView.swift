import SwiftUI

/// 앱 루트 — AppModel을 한 번 생성해 환경으로 내려보내고,
/// View 전용 API인 `.onChange`/`.task` 배선만 담당하는 얇은 껍데기.
/// 실제 화면은 RoomView(공간 UI), 로직은 AppModel에 있다.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var app = AppModel()

    var body: some View {
        RoomView()
            .environment(app)
            .task {
                await app.manager.endOrphanedActivities()
                // 설정 앱에서 Live Activity 허용을 바꾸고 돌아온 경우를 반영 (뷰가 사라지면 자동 취소)
                await app.manager.observeAuthorizationUpdates()
            }
            // 감지된 곡/재생 상태가 바뀔 때마다 서버 보고 + Live Activity에 반영
            .onChange(of: app.monitor.currentTrack) { app.syncActivityWithMonitor() }
            .onChange(of: app.monitor.isPlaying) { app.syncActivityWithMonitor() }
            // 친구 presence가 바뀌면(등장/곡 변경/퇴장) Live Activity에 반영
            .onChange(of: app.presence.friends) { app.syncFriendsToActivity() }
            // 사용자가 잠금화면에서 스와이프로 지우는 등 세션이 밖에서 끝난 경우 정리
            .onChange(of: app.manager.isSessionActive) { _, isActive in
                if !isActive { app.handleSessionEnded() }
            }
            // 포그라운드 복귀 시 재연결, 백그라운드 진입 시 stopped 보고 후 연결 종료
            .onChange(of: scenePhase) { _, phase in
                app.handleScenePhase(phase)
            }
    }
}

#Preview {
    ContentView()
}
