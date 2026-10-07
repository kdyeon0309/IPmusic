import AVFoundation

/// 세션 동안 앱을 백그라운드에서도 깨어 있게 하는 무음 오디오 keep-alive.
///
/// 왜 필요한가: Live Activity(노치)는 앱 프로세스만 갱신할 수 있는데, 무료 Apple 계정은
/// APNs(서버 push)를 못 쓴다. iOS는 백그라운드 앱을 수 초 내에 정지시키므로, 정지되면
/// 곡 변경 감지도 친구 presence 수신도 멈춘다. `UIBackgroundModes: audio` + 무음 재생으로
/// 세션 동안 프로세스를 유지한다 (`.mixWithOthers`라 애플뮤직 재생을 방해하지 않음).
///
/// 트레이드오프: 세션 중 배터리 소모 증가. 세션 종료(`stop()`) 시 즉시 해제된다.
import Observation

@MainActor
@Observable
final class BackgroundKeepAlive {
    private var player: AVAudioPlayer?

    /// 시작 실패 시 원인 (디버그 패널 표시용).
    private(set) var lastError: String?

    nonisolated init() {}

    var isActive: Bool { player?.isPlaying ?? false }

    func start() {
        guard player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            let silence = Self.makeSilentWAV(seconds: 1)
            let player = try AVAudioPlayer(data: silence)
            player.numberOfLoops = -1  // 무한 루프
            player.volume = 0
            player.play()
            self.player = player
            lastError = nil
        } catch {
            // keep-alive 실패는 치명적이지 않다 — 포그라운드 동작은 그대로.
            lastError = "백그라운드 유지 시작 실패: \(error.localizedDescription)"
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// 1초짜리 무음 16-bit mono 8kHz WAV를 메모리에서 생성한다 (번들 리소스 불필요).
    private static func makeSilentWAV(seconds: Int) -> Data {
        let sampleRate: UInt32 = 8000
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let dataSize = UInt32(seconds) * sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        var data = Data()
        func append(_ string: String) { data.append(string.data(using: .ascii)!) }
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        append("RIFF"); append(UInt32(36 + dataSize)); append("WAVE")
        append("fmt "); append(UInt32(16)); append(UInt16(1))  // PCM
        append(channels); append(sampleRate); append(byteRate); append(blockAlign); append(bitsPerSample)
        append("data"); append(dataSize)
        data.append(Data(count: Int(dataSize)))  // 전부 0 = 무음
        return data
    }
}
