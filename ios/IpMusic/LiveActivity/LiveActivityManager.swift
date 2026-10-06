import ActivityKit
import Foundation
import Observation

/// 음악 감상 Live Activity의 시작/갱신/종료를 담당하는 매니저.
///
/// WU3 범위: 실제 재생 감지(MusicKit/MediaPlayer) 없이, 목(mock) 데이터로만 Live Activity를
/// 구동하여 다이나믹 아일랜드 UI를 시뮬레이터에서 검증할 수 있도록 한다.
@MainActor
@Observable
final class LiveActivityManager {
    /// 현재 실행 중인 Live Activity.
    private var activity: Activity<MusicActivityAttributes>?

    /// 가장 최근에 반영한 상태값. 세션 종료 시 마지막 상태를 재사용하기 위해 보관한다.
    private var lastState: MusicActivityAttributes.ContentState?

    /// Live Activity 상태(스와이프 해제 등)를 관찰하는 태스크.
    private var stateObservationTask: Task<Void, Never>?

    /// 세션(Live Activity)이 현재 활성 상태인지 여부.
    private(set) var isSessionActive: Bool = false

    /// 가장 최근에 발생한 오류 메시지 (사용자에게 그대로 노출 가능한 한국어 문구).
    private(set) var lastError: String?

    /// 시스템 설정에서 Live Activity가 허용되어 있는지 여부.
    ///
    /// 저장 프로퍼티인 이유: @Observable은 계산 프로퍼티를 추적하지 못하므로,
    /// `observeAuthorizationUpdates()`가 시스템 스트림으로 이 값을 갱신한다.
    private(set) var areActivitiesEnabled: Bool = ActivityAuthorizationInfo().areActivitiesEnabled

    /// strict concurrency 모드에서도 @State 기본값 위치에서 생성 가능하도록 nonisolated로 선언.
    nonisolated init() {}

    /// 목 데이터로 새 Live Activity 세션을 시작한다.
    /// - Parameters:
    ///   - characterEmoji: 세션 동안 고정되는 내 캐릭터 이모지.
    ///   - title: 트랙 제목.
    ///   - artist: 아티스트 이름.
    func start(characterEmoji: String, title: String, artist: String) {
        guard activity == nil else {
            return
        }

        guard areActivitiesEnabled else {
            lastError = "Live Activity가 비활성화되어 있습니다. 설정 앱에서 이 앱의 Live Activity를 허용해주세요."
            return
        }

        let state = MusicActivityAttributes.ContentState(
            trackTitle: title,
            artistName: artist,
            isPlaying: true,
            changedAt: Date()
        )

        do {
            let activity = try Activity.request(
                attributes: MusicActivityAttributes(characterEmoji: characterEmoji),
                content: ActivityContent(state: state, staleDate: nil)
            )
            self.activity = activity
            self.lastState = state
            self.isSessionActive = true
            self.lastError = nil
            observeActivityState(activity)
        } catch {
            lastError = "Live Activity 시작에 실패했습니다: \(error.localizedDescription)"
        }
    }

    /// 진행 중인 Live Activity의 트랙 정보를 갱신한다.
    /// - Parameters:
    ///   - title: 트랙 제목.
    ///   - artist: 아티스트 이름.
    ///   - isPlaying: 재생 중이면 true, 일시정지면 false.
    func update(title: String, artist: String, isPlaying: Bool) async {
        guard let activity else {
            return
        }

        let state = MusicActivityAttributes.ContentState(
            trackTitle: title,
            artistName: artist,
            isPlaying: isPlaying,
            changedAt: Date()
        )

        await activity.update(ActivityContent(state: state, staleDate: nil))
        lastState = state
    }

    /// 진행 중인 Live Activity를 종료한다.
    func end() async {
        // 연타 방어: await 전에 소유권을 회수해 두 번째 호출이 즉시 반환되게 한다.
        guard let activity else {
            return
        }
        self.activity = nil
        self.isSessionActive = false
        self.lastError = nil
        stateObservationTask?.cancel()
        stateObservationTask = nil

        let finalState = MusicActivityAttributes.ContentState(
            trackTitle: lastState?.trackTitle ?? "",
            artistName: lastState?.artistName ?? "",
            isPlaying: false,
            changedAt: Date()
        )
        lastState = nil

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
    }

    /// 이전 실행(크래시 등)에서 남아있을 수 있는 Live Activity를 모두 정리한다.
    ///
    /// 앱 실행 시점에 호출하여, 재시작 전 세션이 화면에 계속 남아있는 것을 방지한다.
    /// 현재 진행 중인 세션은 제외한다 (뷰 재생성으로 재호출돼도 안전).
    func endOrphanedActivities() async {
        for activity in Activity<MusicActivityAttributes>.activities
        where activity.id != self.activity?.id {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    /// 시스템의 Live Activity 허용 여부 변경을 관찰한다.
    ///
    /// 사용자가 설정 앱에서 허용을 켜고 돌아왔을 때 경고 배너가 즉시 사라지도록 한다.
    /// 뷰의 `.task`에서 호출 — 뷰가 사라지면 자동 취소된다.
    func observeAuthorizationUpdates() async {
        for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
            areActivitiesEnabled = enabled
        }
    }

    /// 사용자가 잠금화면에서 Live Activity를 직접 지우거나(스와이프),
    /// 시스템이 종료(8시간 초과 등)했을 때 앱 내 상태를 동기화한다.
    private func observeActivityState(_ activity: Activity<MusicActivityAttributes>) {
        stateObservationTask?.cancel()
        stateObservationTask = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard state == .dismissed || state == .ended else { continue }
                guard let self, self.activity?.id == activity.id else { return }
                self.activity = nil
                self.isSessionActive = false
                return
            }
        }
    }
}
