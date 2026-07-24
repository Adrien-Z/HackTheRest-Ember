import AVFoundation
import SwiftUI

struct WhiteNoiseView: View {
    @StateObject private var player = WhiteNoisePlayer()

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 26) {
                Spacer()
                ZStack {
                    Circle().fill(Theme.cool.opacity(player.isPlaying ? 0.22 : 0.08)).frame(width: 176, height: 176)
                    Circle().stroke(Theme.cool.opacity(0.55), lineWidth: 1).frame(width: 142, height: 142)
                    Image(systemName: player.isPlaying ? "water.waves" : "water.waves.slash")
                        .font(.system(size: 48, weight: .light)).foregroundStyle(Theme.cool)
                }
                .scaleEffect(player.isPlaying ? 1.04 : 1)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: player.isPlaying)

                VStack(spacing: 7) {
                    Text("Flowing Stream").font(.title2.weight(.bold))
                    Text("A gentle, low-flow water sound for winding down.").font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Volume").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(player.volume * 100))%").font(.caption).foregroundStyle(.secondary)
                    }
                    Slider(value: $player.volume, in: 0.01...1.0).tint(Theme.cool)
                }
                .padding(16).emberCard(0)

                Button { player.toggle() } label: {
                    Label(player.isPlaying ? "Stop Stream" : "Play Stream",
                          systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 54)
                        .foregroundStyle(.white)
                        .background(Theme.emberGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let error = player.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange) }
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Flowing Stream")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }
}

@MainActor
private final class WhiteNoisePlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var volume: Float = 0.07 { didSet { engine.mainMixerNode.outputVolume = volume } }
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    func toggle() { isPlaying ? stop() : start() }

    func start() {
        guard !isPlaying else { return }
        errorMessage = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            // Smooth the random signal heavily to remove the harsh high frequencies
            // of white noise, yielding a low, continuous water-like wash instead.
            var seed: UInt64 = 0x9E3779B97F4A7C15
            var lowPass: Float = 0
            let source = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in buffers {
                    let samples = buffer.mData!.assumingMemoryBound(to: Float.self)
                    for frame in 0..<Int(frameCount) {
                        seed = seed &* 2862933555777941757 &+ 3037000493
                        let white = Float(seed >> 40) / Float(1 << 24) * 2 - 1
                        lowPass = lowPass * 0.985 + white * 0.015
                        samples[frame] = lowPass * 0.68
                    }
                }
                return noErr
            }
            sourceNode = source
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = volume
            try engine.start()
            isPlaying = true
        } catch {
            errorMessage = "Stream sounds could not start. Please try again."
            stop()
        }
    }

    func stop() {
        engine.stop()
        if let sourceNode {
            engine.disconnectNodeInput(sourceNode)
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }
        sourceNode = nil
        isPlaying = false
    }
}

struct BreathingTrainingView: View {
    @State private var cycleStartedAt = Date()

    var body: some View {
        ZStack {
            NightBackground()
            TimelineView(.periodic(from: .now, by: 0.05)) { timeline in
                let phase = BreathPhase(elapsed: timeline.date.timeIntervalSince(cycleStartedAt))
                VStack(spacing: 26) {
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.mint.opacity(0.12)).frame(width: 250, height: 250)
                        Circle().fill(Theme.mint.opacity(0.28)).frame(width: 176, height: 176).scaleEffect(phase.scale)
                        Circle().stroke(Theme.mint.opacity(0.75), lineWidth: 2).frame(width: 132, height: 132).scaleEffect(phase.scale)
                        VStack(spacing: 5) {
                            Text(phase.instruction).font(.title2.weight(.bold))
                            Text("\(phase.secondsRemaining)s").font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                    .animation(.linear(duration: 0.08), value: phase.scale)

                    VStack(spacing: 7) {
                        Text("4 · 4 · 6 breathing").font(.title3.weight(.bold))
                        Text("Inhale for 4, hold for 4, then exhale slowly for 6.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Button("Restart") { cycleStartedAt = Date() }.buttonStyle(.borderedProminent).tint(Theme.mint)
                    Spacer()
                }
                .padding(24)
            }
        }
        .navigationTitle("Breathing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BreathPhase {
    let instruction: String
    let secondsRemaining: Int
    let scale: CGFloat

    init(elapsed: TimeInterval) {
        let position = elapsed.truncatingRemainder(dividingBy: 14)
        if position < 4 {
            instruction = "Breathe in"
            secondsRemaining = max(1, 4 - Int(position))
            scale = 0.72 + CGFloat(position / 4) * 0.30
        } else if position < 8 {
            instruction = "Hold"
            secondsRemaining = max(1, 8 - Int(position))
            scale = 1.02
        } else {
            instruction = "Breathe out"
            secondsRemaining = max(1, 14 - Int(position))
            scale = 1.02 - CGFloat((position - 8) / 6) * 0.30
        }
    }
}

struct QuickToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Spacer(minLength: 4)
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.18), lineWidth: 0.8))
    }
}
