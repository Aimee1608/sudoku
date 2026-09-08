import AVFoundation

/// 音效全部是代码现场合成的,不打包任何音频文件。没有背景音乐——数独是安静的解谜,
/// 一局十几分钟,循环曲子只会让人想关掉。
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var cache: [GameState.Feedback: [AVAudioPCMBuffer]] = [:]
    private var started = false

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ feedback: GameState.Feedback, enabled: Bool) {
        guard enabled, ensureRunning() else { return }
        let buffers = cache[feedback] ?? build(feedback)
        cache[feedback] = buffers
        var when: AVAudioTime?
        for (i, buffer) in buffers.enumerated() {
            if i == 0 {
                player.scheduleBuffer(buffer, at: nil)
            } else {
                // 琶音靠采样帧排期,不用 asyncAfter——后者在滑动/动画时会被主线程挤歪
                let offset = AVAudioFramePosition(Double(i) * 0.11 * format.sampleRate)
                let base = player.lastRenderTime.flatMap { player.playerTime(forNodeTime: $0) }
                let start = (base?.sampleTime ?? 0) + offset
                when = AVAudioTime(sampleTime: start, atRate: format.sampleRate)
                player.scheduleBuffer(buffer, at: when)
            }
        }
        if !player.isPlaying { player.play() }
    }

    /// 频繁触发的音必须很轻:选格和填数每局要响上百次,音量跟通关一样的话做几题就想静音了。
    private func build(_ feedback: GameState.Feedback) -> [AVAudioPCMBuffer] {
        switch feedback {
        case .select:
            return [tone(784, 0.05, 0.05)]
        case .note:
            return [tone(523.25, 0.05, 0.05)]
        case .erase:
            return [tone(392, 0.07, 0.06)]
        case .place:
            return [tone(659.25, 0.07, 0.09), tone(987.77, 0.09, 0.07)]
        case .wrong:
            return [tone(233.08, 0.10, 0.11), tone(174.61, 0.16, 0.10)]
        case .unitDone:
            return [tone(659.25, 0.10, 0.10), tone(830.61, 0.10, 0.10), tone(1046.5, 0.20, 0.11)]
        case .win:
            return [tone(523.25, 0.16, 0.12), tone(659.25, 0.16, 0.12),
                    tone(783.99, 0.16, 0.12), tone(1046.5, 0.34, 0.13)]
        }
    }

    @discardableResult
    private func ensureRunning() -> Bool {
        if started { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            engine.prepare()
            try engine.start()
            started = true
            return true
        } catch {
            // 没有音频设备时静默放弃,音效只是锦上添花,不该影响对局
            return false
        }
    }

    /// 正弦基频叠一点二次谐波,纯正弦听着太"电子",数独要频繁响,音色得柔和。
    private func tone(_ frequency: Double, _ duration: Double, _ amplitude: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let channel = buffer.floatChannelData![0]
        let attack = 0.008
        let release = duration * 0.65
        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            let env: Double
            if t < attack {
                env = t / attack
            } else if t > duration - release {
                env = max(0, (duration - t) / release)
            } else {
                env = 1
            }
            let wave = sin(2 * .pi * frequency * t) + 0.22 * sin(4 * .pi * frequency * t)
            channel[frame] = Float(wave * amplitude * env)
        }
        return buffer
    }
}
