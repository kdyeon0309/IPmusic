import Foundation
import Observation

/// URLSessionWebSocketTask 래퍼 — 자동 재연결(지수 백오프)을 담당한다.
///
/// 역할을 좁게 유지한다: 텍스트를 보내고(`send`), 받은 텍스트를 콜백으로 넘긴다(`onText`).
/// 메시지 해석(JSON 인코딩/디코딩)은 PresenceService의 몫.
@MainActor
@Observable
final class WebSocketClient {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
    }

    private(set) var state: ConnectionState = .disconnected

    /// 서버에서 텍스트 메시지를 받을 때마다 호출된다 (MainActor에서).
    var onText: ((String) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var runLoopTask: Task<Void, Never>?
    private var url: URL?

    /// 재연결 대기 시간. 실패할 때마다 2배(최대 15초), 연결 성공 시 1초로 리셋.
    private var reconnectDelay: Duration = .seconds(1)

    /// connect/disconnect로 제어되는 "연결을 유지해야 하는가" 플래그.
    private var shouldStayConnected = false

    nonisolated init() {}

    /// 연결을 시작하고, 끊기면 백오프 후 자동 재연결한다.
    func connect(to url: URL) {
        self.url = url
        shouldStayConnected = true
        guard runLoopTask == nil else { return }
        runLoopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    /// 재연결을 멈추고 연결을 닫는다.
    func disconnect() {
        shouldStayConnected = false
        runLoopTask?.cancel()
        runLoopTask = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        state = .disconnected
    }

    /// 텍스트 한 건을 전송한다. 연결이 없으면 조용히 무시된다
    /// (재연결 후 heartbeat가 최신 상태를 다시 보내므로 유실돼도 괜찮다).
    func send(_ text: String) async {
        guard let task else { return }
        do {
            try await task.send(.string(text))
        } catch {
            // 전송 실패 = 연결이 죽었다는 신호. receive 쪽 에러가 재연결을 트리거한다.
        }
    }

    /// 연결 → 수신 루프 → 끊기면 백오프 후 재시도.
    private func runLoop() async {
        while shouldStayConnected, !Task.isCancelled {
            guard let url else { return }

            state = .connecting
            let task = URLSession.shared.webSocketTask(with: url)
            self.task = task
            task.resume()
            state = .connected
            reconnectDelay = .seconds(1)

            do {
                while shouldStayConnected {
                    let message = try await task.receive()
                    if case .string(let text) = message {
                        onText?(text)
                    }
                }
            } catch {
                // 서버 다운, 네트워크 전환 등 — 아래에서 재연결
            }

            task.cancel(with: .goingAway, reason: nil)
            self.task = nil
            state = .disconnected

            guard shouldStayConnected else { break }
            try? await Task.sleep(for: reconnectDelay)
            reconnectDelay = min(reconnectDelay * 2, .seconds(15))
        }
        runLoopTask = nil
    }
}
