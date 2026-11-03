import AVFoundation
import Foundation

/// Ciche dźwięki z AVAudioEngine. Kategoria .ambient: przełącznik wyciszenia iPhone'a je wycisza
/// i nie przerywają muzyki z innych aplikacji.
final class Sound {
    static let shared = Sound()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var ready = false
    private var lastClick = Date.distantPast

    var enabled: Bool {
        L.defaults.object(forKey: "sounds") as? Bool ?? true
    }

    private init() {}

    private func start() -> Bool {
        if ready { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
        return ready
    }

    /// (częstotliwość Hz, start s, długość s, głośność)
    private func play(_ notes: [(Double, Double, Double, Float)], wave: @escaping (Double) -> Double = { sin($0) }) {
        guard enabled else { return }
        DispatchQueue.main.async { [self] in
            guard start() else { return }
            if !engine.isRunning { try? engine.start() }
            let total = notes.map { $0.1 + $0.2 }.max() ?? 0.1
            let rate = format.sampleRate
            let frames = AVAudioFrameCount(total * rate + 200)
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let ch = buf.floatChannelData?[0] else { return }
            buf.frameLength = frames
            for i in 0 ..< Int(frames) { ch[i] = 0 }
            for (freq, startAt, dur, gain) in notes {
                let s0 = Int(startAt * rate)
                let n = Int(dur * rate)
                for i in 0 ..< n where s0 + i < Int(frames) {
                    let t = Double(i) / rate
                    let attack = min(1, t / 0.006)
                    let env = attack * exp(-5 * t / dur)
                    ch[s0 + i] += Float(wave(2 * .pi * freq * t) * env) * gain
                }
            }
            player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
            if !player.isPlaying { player.play() }
        }
    }

    func click() {
        guard Date().timeIntervalSince(lastClick) > 0.12 else { return }
        lastClick = Date()
        play([(1800, 0, 0.03, 0.05)])
    }

    func tab() {
        guard Date().timeIntervalSince(lastClick) > 0.12 else { return }
        lastClick = Date()
        play([(1200, 0, 0.04, 0.05)])
    }

    func coin() { play([(1568, 0, 0.09, 0.09), (2093, 0.07, 0.25, 0.08)]) }
    func withdraw() { play([(784, 0, 0.12, 0.08), (587, 0.1, 0.12, 0.08), (440, 0.2, 0.22, 0.07)]) }
    func remove() { play([(140, 0, 0.08, 0.14)], wave: { sin($0) > 0 ? 1 : -1 }) }
    func chord() { play([(523, 0, 0.5, 0.05), (659, 0.03, 0.5, 0.05), (784, 0.06, 0.55, 0.05)]) }
}
