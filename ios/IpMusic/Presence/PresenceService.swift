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
    private var reconcileTask: Task<Void, Never>?

    /// 친구별 마지막 push 수신 시각. 재접속 후 스냅샷으로 재확인되지 않은(=그 사이 퇴장한)
    /// 친구를 정리하는 데 쓴다.
    private var lastPushAt: [String: Date] = [:]

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
        reconcileAfterSnapshot()
        resendMyCustomization()
    }

    /// 접속할 때마다 저장된 내 꾸미기를 1회 재전송한다 — 서버가 재시작해
    /// 메모리 Directory가 초기화됐어도 멱등하게 복구된다.
    private func resendMyCustomization() {
        let defaults = UserDefaults.standard
        guard let accessory = defaults.string(forKey: "myAccessory") else { return }
        let theme = defaults.string(forKey: "myRoomTheme") ?? "cream"
        sendCustomization(accessory: accessory, roomTheme: theme)
    }

    /// 내 캐릭터 꾸미기 변경을 서버에 보낸다 (저장은 호출 측 @AppStorage 몫).
    func sendCustomization(accessory: String, roomTheme: String) {
        let message = SetCustomizationMessage(accessory: accessory, roomTheme: roomTheme)
        Task {
            await send(message)
        }
    }

    /// 접속 직후 서버가 보내는 스냅샷이 도착할 시간을 준 뒤, 스냅샷으로 재확인되지
    /// 않은 친구(백그라운드 사이에 퇴장한 친구)를 목록에서 정리한다.
    private func reconcileAfterSnapshot() {
        let connectedAt = Date()
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            self.friends.removeAll { friend in
                (self.lastPushAt[friend.id] ?? .distantPast) < connectedAt
            }
        }
    }

    /// stopped를 보고하고 연결을 닫는다.
    /// - Parameter clearFriends: true면 친구 목록도 비운다 (세션 종료 시).
    ///   백그라운드 진입 시엔 false — 노치(Live Activity)는 앱이 없는 동안에도 떠 있으므로,
    ///   여기서 비우면 "노치를 보는 순간 친구가 사라지는" 현상이 생긴다.
    ///   대신 포그라운드 복귀 시 서버 스냅샷으로 최신 상태가 복구된다.
    func disconnect(clearFriends: Bool = false) async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        reconcileTask?.cancel()
        reconcileTask = nil
        lastReport = nil
        if isConnected {
            await send(StoppedReport())
        }
        client.disconnect()
        if clearFriends {
            friends = []
        }
    }

    /// 내 now-playing을 서버에 보고한다. 곡/재생 상태가 바뀔 때마다 호출.
    func report(title: String, artist: String, isPlaying: Bool, storeId: String? = nil) {
        let report = NowPlayingReport(
            track: title, artist: artist, isPlaying: isPlaying, storeId: storeId ?? ""
        )
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

    /// 서버 push의 type 필드만 먼저 들여다보기 위한 최소 디코딩용 타입.
    private struct TypePeek: Decodable {
        let type: String
    }

    /// 수신 멀티플렉싱: type을 먼저 읽고 메시지별 핸들러로 분기한다.
    /// 모르는 타입은 조용히 무시 — 서버가 먼저 새 타입을 추가해도 안전(전방 호환).
    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let peek = try? PresenceMessage.decoder.decode(TypePeek.self, from: data) else { return }
        switch peek.type {
        case "friend_presence": handlePresence(data)
        case "friend_bubble": handleBubble(data)
        case "friend_recommendation": handleRecommendation(data)
        default: break
        }
    }

    private func handlePresence(_ data: Data) {
        guard let push = try? PresenceMessage.decoder.decode(FriendPresencePush.self, from: data) else { return }

        lastPushAt[push.friendId] = Date()

        if push.event == "stopped" {
            friends.removeAll { $0.id == push.friendId }
            return
        }

        let friend = FriendState(
            id: push.friendId,
            emoji: push.emoji,
            accessory: push.accessory ?? "",
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

    // MARK: - 말풍선 (M2)

    /// 친구 말풍선 수신 콜백 (fromId, text). AppModel이 배선해 방 UI에 10초 표시한다.
    var onBubble: ((String, String) -> Void)?

    /// 친구에게 말풍선을 보낸다. 비영속 — 상대가 오프라인이면 서버에서 유실된다.
    func sendBubble(to friendId: String, text: String) {
        let message = BubbleSendMessage(to: friendId, text: text)
        Task {
            await send(message)
        }
    }

    private func handleBubble(_ data: Data) {
        guard let push = try? PresenceMessage.decoder.decode(FriendBubblePush.self, from: data) else { return }
        onBubble?(push.fromId, push.text)
    }

    // MARK: - 곡 추천 (M2)

    /// 받은 추천 — 확인(ack)하면 제거된다. 접속 시 서버 pending도 여기로 쌓인다.
    private(set) var pendingRecommendations: [FriendRecommendation] = []

    /// 친구에게 지금 듣는 곡을 추천한다. 영속 — 오프라인 친구도 다음 접속 시 받는다.
    func sendRecommendation(to friendId: String, track: String, artist: String, storeId: String?) {
        let message = RecommendSendMessage(
            to: friendId, track: track, artist: artist, storeId: storeId ?? ""
        )
        Task {
            await send(message)
        }
    }

    /// 추천을 확인 처리한다 — 서버에 ack를 보내고 로컬 목록에서 제거.
    func ackRecommendation(id: Int) {
        pendingRecommendations.removeAll { $0.id == id }
        let message = RecommendationAckMessage(recommendationId: id)
        Task {
            await send(message)
        }
    }

    private func handleRecommendation(_ data: Data) {
        guard let push = try? PresenceMessage.decoder.decode(FriendRecommendationPush.self, from: data) else { return }
        // 재접속 시 pending이 중복으로 올 수 있으므로 id로 멱등 처리
        guard !pendingRecommendations.contains(where: { $0.id == push.id }) else { return }
        pendingRecommendations.append(FriendRecommendation(
            id: push.id,
            fromId: push.fromId,
            fromEmoji: push.fromEmoji,
            track: push.track,
            artist: push.artist,
            storeId: push.storeId.isEmpty ? nil : push.storeId
        ))
    }
}

/// 받은 곡 추천 1건 (로컬 표시용).
struct FriendRecommendation: Identifiable, Hashable {
    let id: Int
    let fromId: String
    let fromEmoji: String
    let track: String
    let artist: String
    let storeId: String?
}
