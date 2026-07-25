import AVFoundation
import SwiftUI

struct WhiteNoiseView: View {
    @StateObject private var player = WhiteNoisePlayer()
    @State private var selectedSound: AmbientSound = .stream

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 26) {
                Spacer()
                TabView(selection: $selectedSound) {
                    ForEach(AmbientSound.allCases) { sound in
                        VStack(spacing: 16) {
                            ZStack {
                                Circle().fill(sound.tint.opacity(player.isPlaying ? 0.22 : 0.08)).frame(width: 176, height: 176)
                                Circle().stroke(sound.tint.opacity(0.55), lineWidth: 1).frame(width: 142, height: 142)
                                Image(systemName: sound.icon)
                                    .font(.system(size: 48, weight: .light)).foregroundStyle(sound.tint)
                            }
                            .scaleEffect(player.isPlaying ? 1.04 : 1)
                            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: player.isPlaying)
                            VStack(spacing: 7) {
                                Text(sound.title).font(.title2.weight(.bold))
                                Text(sound.description).font(.subheadline).foregroundStyle(Theme.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .tag(sound)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 272)
                .onChange(of: selectedSound) { sound in player.select(sound) }

                HStack(spacing: 7) {
                    ForEach(AmbientSound.allCases) { sound in
                        Capsule()
                            .fill(sound == selectedSound ? Theme.ember : Color.white.opacity(0.22))
                            .frame(width: sound == selectedSound ? 18 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: selectedSound)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Ambient sound \(AmbientSound.allCases.firstIndex(of: selectedSound)! + 1) of \(AmbientSound.allCases.count)")

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Volume").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(player.volume * 100))%").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                    Slider(value: $player.volume, in: 0.01...1.0).tint(selectedSound.tint)
                }
                .padding(16).emberCard(0)

                Button { player.toggle() } label: {
                    Label(player.isPlaying ? "Stop \(selectedSound.title)" : "Play \(selectedSound.title)",
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
        .navigationTitle("Ambient Sounds")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }
}

private enum AmbientSound: String, CaseIterable, Identifiable {
    case stream, rain, birds

    var id: String { rawValue }
    var title: String {
        switch self {
        case .stream: return "Flowing Stream"
        case .rain: return "Soft Rain"
        case .birds: return "Morning Birds"
        }
    }
    var description: String {
        switch self {
        case .stream: return "A gentle, low-flow water sound for winding down."
        case .rain: return "A calm, steady rainfall with a soft texture."
        case .birds: return "Light, spacious birdsong for a peaceful reset."
        }
    }
    var icon: String {
        switch self {
        case .stream: return "water.waves"
        case .rain: return "cloud.rain.fill"
        case .birds: return "bird.fill"
        }
    }
    var tint: Color {
        switch self {
        case .stream: return Theme.cool
        case .rain: return Theme.mint
        case .birds: return Theme.amber
        }
    }
}

@MainActor
private final class WhiteNoisePlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var volume: Float = 0.07 { didSet { engine.mainMixerNode.outputVolume = volume } }
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sound: AmbientSound = .stream

    func toggle() { isPlaying ? stop() : start() }

    func select(_ sound: AmbientSound) {
        guard self.sound != sound else { return }
        let shouldResume = isPlaying
        stop()
        self.sound = sound
        if shouldResume { start() }
    }

    func start() {
        guard !isPlaying else { return }
        errorMessage = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            var seed: UInt64 = 0x9E3779B97F4A7C15
            var lowPass: Float = 0
            var highPass: Float = 0
            var phase: Float = 0
            var chirpRemaining = 0
            var chirpFrequency: Float = 0
            let selectedSound = sound
            let sampleRate = Float(format.sampleRate)
            let source = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in buffers {
                    let samples = buffer.mData!.assumingMemoryBound(to: Float.self)
                    for frame in 0..<Int(frameCount) {
                        seed = seed &* 2862933555777941757 &+ 3037000493
                        let white = Float(seed >> 40) / Float(1 << 24) * 2 - 1
                        switch selectedSound {
                        case .stream:
                            lowPass = lowPass * 0.985 + white * 0.015
                            samples[frame] = lowPass * 0.68
                        case .rain:
                            lowPass = lowPass * 0.82 + white * 0.18
                            highPass = highPass * 0.985 + lowPass * 0.015
                            samples[frame] = (lowPass - highPass) * 0.32
                        case .birds:
                            // Short, infrequent sine chirps over a near-silent bed;
                            // the sparse envelope keeps this restful rather than busy.
                            if chirpRemaining == 0, seed % 18_000 < 7 {
                                chirpRemaining = Int(sampleRate * 0.12)
                                chirpFrequency = 1_850 + Float(seed % 950)
                            }
                            if chirpRemaining > 0 {
                                let progress = 1 - Float(chirpRemaining) / (sampleRate * 0.12)
                                let envelope = sin(Float.pi * progress)
                                phase += 2 * Float.pi * (chirpFrequency * (1 + progress * 0.18)) / sampleRate
                                samples[frame] = sin(phase) * envelope * 0.18
                                chirpRemaining -= 1
                            } else {
                                lowPass = lowPass * 0.998 + white * 0.002
                                samples[frame] = lowPass * 0.035
                            }
                        }
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
            errorMessage = "Ambient sounds could not start. Please try again."
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
                            Text("\(phase.secondsRemaining)s").font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .animation(.linear(duration: 0.08), value: phase.scale)

                    VStack(spacing: 7) {
                        Text("4 · 4 · 6 breathing").font(.title3.weight(.bold))
                        Text("Inhale for 4, hold for 4, then exhale slowly for 6.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
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

struct WindDownRitualsView: View {
    private let rituals: [WindDownRitual] = [
        WindDownRitual(
            title: "Foot Bath",
            subtitle: "10-12 min comfortable warmth",
            icon: "thermometer.sun.fill",
            tint: Theme.ember,
            steps: [
                "Use warm water that feels comfortable, never scalding.",
                "Finish 45-90 min before lights-out.",
                "Dry fully and keep feet comfortably warm."
            ],
            note: "A foot bath fits EMBER's thermal wind-down: warm the periphery, then let the body cool into sleep."),
        WindDownRitual(
            title: "Warm Towel",
            subtitle: "Low-effort warmth for busy nights",
            icon: "towel.fill",
            tint: Theme.amber,
            steps: [
                "Warm a towel and place it around shoulders, neck, or feet.",
                "Keep lights low and avoid checking messages.",
                "Stop before you feel sweaty or overheated."
            ],
            note: "Use this when a full bath is too much; the goal is comfort and a clean transition."),
        WindDownRitual(
            title: "Tea Cutoff",
            subtitle: "Coffee and tea both count",
            icon: "cup.and.saucer.fill",
            tint: Theme.mint,
            steps: [
                "Treat strong tea, milk tea, coffee, and energy drinks as caffeine.",
                "Move meaningful caffeine earlier in the afternoon.",
                "Choose herbal or explicitly low-caffeine tea for the bedtime ritual."
            ],
            note: "Tea caffeine varies by leaves, serving size, and steep time, so the safer late-night rule is simple."),
        WindDownRitual(
            title: "Gentle Reset",
            subtitle: "Baduanjin-inspired mobility",
            icon: "figure.mind.and.body",
            tint: Theme.cool,
            steps: [
                "Use slow shoulder rolls, side bends, or easy standing stretches.",
                "Breathe through the nose and keep effort light.",
                "Stop if it becomes workout-like or stimulating."
            ],
            note: "This borrows the calm pacing of traditional movement without treating it as medicine.")
    ]

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        title: "Wind-down rituals",
                        subtitle: "Science-first routines shaped by warmth, tea awareness, and low-arousal movement.")
                    ForEach(rituals) { ritual in
                        RitualCard(ritual: ritual)
                    }
                    ScienceNote(
                        text: "These are comfort routines, not medical treatment. EMBER uses them to make the evening transition repeatable and easy to follow.",
                        icon: "checkmark.seal")
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Rituals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WindDownRitual: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let steps: [String]
    let note: String
}

private struct RitualCard: View {
    let ritual: WindDownRitual

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: ritual.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ritual.tint)
                    .frame(width: 42, height: 42)
                    .background(ritual.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(ritual.title).font(.headline)
                    Text(ritual.subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ritual.steps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ritual.tint)
                            .padding(.top, 2)
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.92))
                    }
                }
            }
            Text(ritual.note)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .emberCard(0)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(ritual.tint.opacity(0.16), lineWidth: 0.8))
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
            Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.18), lineWidth: 0.8))
    }
}
