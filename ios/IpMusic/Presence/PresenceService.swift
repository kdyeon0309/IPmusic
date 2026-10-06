import Foundation
import Observation

/// presence 동기화 서비스 — 자가보고(내 곡 → 서버)와 친구 상태 수신(서버 → `friends`)을 담당.
///
/// - 보고: `report(...)`가 즉시 전송 + 30초 주기 heartbeat로 재전송 (서버 TTL 90초의 생존 신호).
/// - 수신: friend_presence push를 해석해 `friends` 배열을 갱신 (playing → upsert, stopped → 제거).
@MainActor
@Observable
final class PresenceService {
    /// 지금 음악을 듣고 있는 친구들. Live Activity 페이로드 예산(4KB) 때문에 최대 3명으로 캡.
    private(set) var friends: [FriendState] = []

    var isConnected: Bool {
        client.state == .connected
    }

    private static let maxFriends = 3
    private static let heartbeatInterval: Duration = .seconds(30)

    private let client = WebSocketClient()
    private var heartbeatTask: Task<Void, Never>?

    /// 마지막 자가보고. heartbeat와 재연결 직후 재전송에 쓴다.
    private var lastReport: NowPlayingReport?

    nonisolated init() {}

    /// 서버에 연결하고 heartbeat를 시작한다. 포그라운드 진입 시 호출.
    func connect() {
        client.onText = { [weak self] text in
            self?.handle(text)
        }
        client.connect(to: AppConfig.wsURL)
        startHeartbeat()
    }

    /// stopped를 보고하고 연결을 닫는다. 백그라운드 진입/세션 종료 시 호출.
    func disconnect() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        lastReport = nil
        if isConnected {
            await send(StoppedReport())
        }
        client.disconnect()
        friends = []
    }

    /// 내 now-playing을 서버에 보고한다. 곡/재생 상태가 바뀔 때마다 호출.
    func report(title: String, artist: String, isPlaying: Bool) {
        let report = NowPlayingReport(track: title, artist: artist, isPlaying: isPlaying)
        lastReport = report
        Task {
            await send(report)
        }
    }

    /// "지금은 아무것도 안 듣는다"를 보고한다 (연결은 유지 — 친구 수신은 계속).
    func reportStopped() {
        lastReport = nil
        Task {
            await send(StoppedReport())
        }
    }

    // MARK: - 내부

    private func send(_ message: some Encodable) async {
        guard let data = try? PresenceMessage.encoder.encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        await client.send(text)
    }

    /// 30초마다 마지막 보고를 재전송한다. 재연결 직후에도 이 루프가 상태를 복구한다.
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.heartbeatInterval)
                guard let self, var report = self.lastReport else { continue }
                report.ts = PresenceMessage.nowISO8601()
                self.lastReport = report
                await self.send(report)
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let push = try? PresenceMessage.decoder.decode(FriendPresencePush.self, from: data),
              push.type == "friend_presence" else { return }

        if push.event == "stopped" {
            friends.removeAll { $0.id == push.friendId }
            return
        }

        let friend = FriendState(
            id: push.friendId,
            emoji: push.emoji,
            trackTitle: push.track,
            artistName: push.artist,
            isPlaying: push.isPlaying
        )
        if let index = friends.firstIndex(where: { $0.id == push.friendId }) {
            friends[index] = friend
        } else if friends.count < Self.maxFriends {
            friends.append(friend)
        }
    }
}
