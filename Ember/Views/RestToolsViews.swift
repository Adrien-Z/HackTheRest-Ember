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

                Button {
                    Haptics.light()
                    player.toggle()
                } label: {
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
    @EnvironmentObject private var store: DataStore
    @State private var startedAt = Date()
    @State private var pausedAt: Date? = nil
    @State private var accumulatedPause: TimeInterval = 0
    @State private var lastPhase: CyclicSighPhase.ID? = nil
    @State private var completedCycles = 0

    private let targetSeconds: TimeInterval = 5 * 60

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first {
            $0.id == store.boxSpace.currentUser.decorationID
        }
    }

    var body: some View {
        ZStack {
            NightBackground()
            TimelineView(.periodic(from: .now, by: 0.05)) { timeline in
                let elapsed = effectiveElapsed(at: timeline.date)
                let phase = CyclicSighPhase(elapsed: elapsed)
                let progress = min(1, elapsed / targetSeconds)

                VStack(spacing: 18) {
                    header(progress: progress, elapsed: elapsed)
                    Spacer(minLength: 8)
                    ZStack {
                        breathingHalo(phase: phase)
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Theme.mint.opacity(0.10))
                                    .frame(width: 188, height: 188)
                                    .scaleEffect(phase.lungScale + 0.12)
                                Circle()
                                    .stroke(Theme.mint.opacity(0.28), lineWidth: 1.2)
                                    .frame(width: 210, height: 210)
                                    .scaleEffect(phase.lungScale)
                                Circle()
                                    .stroke(phase.tint.opacity(0.78), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                    .frame(width: 156, height: 156)
                                    .scaleEffect(phase.lungScale)
                                    .shadow(color: phase.tint.opacity(0.32), radius: 16)
                                BoxSkinImageView(
                                    decoration: selectedDecoration,
                                    size: CGSize(width: 92, height: 92)
                                )
                                .scaleEffect(0.90 + phase.breathFill * 0.18)
                                .offset(y: phase.mascotOffset)
                            }

                            VStack(spacing: 5) {
                                Text(phase.title)
                                    .font(.system(.title2, design: .rounded).weight(.heavy))
                                    .foregroundStyle(phase.tint)
                                    .contentTransition(.opacity)
                                Text(phase.subtitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryText)
                                Text("\(phase.secondsRemaining)s")
                                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.18), value: phase.id)
                    .onChange(of: phase.id) { newPhase in
                        phaseHaptic(newPhase)
                    }

                    phaseTrack(phase: phase)
                    controls
                    ScienceNote(
                        text: "Cyclic sighing uses a full inhale, a small top-up inhale, then a longer relaxed exhale. Keep it easy; stop if you feel dizzy.",
                        icon: "wind")
                    Spacer(minLength: 0)
                }
                .padding(24)
            }
        }
        .navigationTitle("Cyclic Sigh")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(progress: Double, elapsed: TimeInterval) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Downshift")
                    .font(.title2.weight(.bold))
                Text("5 min · \(completedCycles) sighs")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.white.opacity(0.10), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.mint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(timeLeft(elapsed))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)
        }
    }

    private func breathingHalo(phase: CyclicSighPhase) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [phase.tint.opacity(0.20), Theme.cool.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
                    .frame(width: 210 + CGFloat(index * 30), height: 210 + CGFloat(index * 30))
                    .rotationEffect(.degrees(Double(index) * 12 + phase.rotation))
                    .scaleEffect(0.90 + phase.breathFill * 0.16 + Double(index) * 0.025)
                    .opacity(0.88 - Double(index) * 0.16)
            }
        }
    }

    private func phaseTrack(phase: CyclicSighPhase) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(CyclicSighPhase.ID.allCases, id: \.self) { id in
                    Capsule()
                        .fill(id == phase.id ? phase.tint : Color.white.opacity(0.12))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            if id == phase.id {
                                Capsule()
                                    .fill(.white.opacity(0.34))
                                    .frame(maxWidth: .infinity)
                                    .scaleEffect(x: phase.phaseProgress, anchor: .leading)
                            }
                        }
                }
            }
            HStack {
                Label("Inhale", systemImage: "arrow.down.to.line.compact")
                Spacer()
                Label("Top up", systemImage: "plus")
                Spacer()
                Label("Exhale", systemImage: "arrow.up")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .background(Theme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.light()
                togglePause()
            } label: {
                Label(pausedAt == nil ? "Pause" : "Resume",
                      systemImage: pausedAt == nil ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.mint)

            Button {
                Haptics.light()
                reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.bordered)
            .tint(Theme.secondaryText)
            .accessibilityLabel("Restart")
        }
    }

    private func effectiveElapsed(at date: Date) -> TimeInterval {
        let referenceDate = pausedAt ?? date
        return max(0, referenceDate.timeIntervalSince(startedAt) - accumulatedPause)
    }

    private func togglePause() {
        if let pausedAt {
            accumulatedPause += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
        } else {
            pausedAt = Date()
        }
    }

    private func reset() {
        startedAt = Date()
        pausedAt = nil
        accumulatedPause = 0
        lastPhase = nil
        completedCycles = 0
    }

    private func phaseHaptic(_ newPhase: CyclicSighPhase.ID) {
        guard newPhase != lastPhase else { return }
        if lastPhase == .exhale, newPhase == .inhale {
            completedCycles += 1
        }
        lastPhase = newPhase
        switch newPhase {
        case .inhale:
            Haptics.light()
        case .topUp:
            Haptics.tick()
        case .exhale:
            Haptics.stream()
        }
    }

    private func timeLeft(_ elapsed: TimeInterval) -> String {
        let remaining = max(0, Int((targetSeconds - elapsed).rounded(.up)))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}

struct MindDumpCoachView: View {
    @EnvironmentObject private var store: DataStore
    @State private var draft = ""
    @State private var thinking = false
    @State private var lastStreamHaptic = Date.distantPast

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first {
            $0.id == store.boxSpace.currentUser.decorationID
        }
    }

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            hero
                            ForEach(store.mindChat) { message in
                                MindDumpBubble(message: message, decoration: selectedDecoration)
                                    .id(message.id)
                            }
                            if thinking && (store.mindChat.last?.content.isEmpty ?? false) {
                                HStack(spacing: 8) {
                                    ProgressView().tint(Theme.amber)
                                    Text("Sorting…")
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("mindThinking")
                            }
                            Color.clear.frame(height: 1).id("mindBottom")
                        }
                        .padding()
                        .lockHorizontal()
                    }
                    .onChange(of: store.mindChat.count) { _ in
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo("mindBottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: store.mindChat.last?.content) { _ in
                        proxy.scrollTo("mindBottom", anchor: .bottom)
                        streamHaptic()
                    }
                }
                inputBar
            }
        }
        .navigationTitle("Mind Dump")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.light()
                    store.resetMindDump()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Reset mind dump")
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 13) {
            BoxSkinImageView(decoration: selectedDecoration, size: CGSize(width: 58, height: 58))
            VStack(alignment: .leading, spacing: 4) {
                Text("Brain dump, then park it")
                    .font(.headline)
                Text("EMBER keeps the thread here and reminds you tomorrow morning.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .emberCard(12)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("What's on your mind?", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.amber)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thinking)
        }
        .padding()
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        Haptics.light()
        draft = ""
        thinking = true
        await store.sendMindDumpMessage(text)
        thinking = false
        Haptics.success()
    }

    private func streamHaptic() {
        guard thinking, Date().timeIntervalSince(lastStreamHaptic) > 0.12 else { return }
        lastStreamHaptic = Date()
        Haptics.stream()
    }
}

private struct MindDumpBubble: View {
    let message: ChatMessage
    let decoration: BoxDecoration?

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if message.role == .coach {
                BoxSkinImageView(decoration: decoration, size: CGSize(width: 34, height: 34))
                    .padding(5)
                    .background(Theme.card.opacity(0.7), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.amber.opacity(0.18), lineWidth: 0.8))
            } else {
                Spacer(minLength: 40)
            }
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(message.role == .user ? .white : .primary.opacity(0.94))
                .padding(12)
                .background(
                    message.role == .user ? Theme.ember.opacity(0.9) : Theme.card.opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .frame(maxWidth: 290, alignment: message.role == .user ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if message.role == .coach {
                Spacer(minLength: 0)
            }
        }
    }
}

private struct CyclicSighPhase {
    enum ID: CaseIterable {
        case inhale
        case topUp
        case exhale
    }

    private static let inhaleDuration = 1.8
    private static let topUpDuration = 0.9
    private static let exhaleDuration = 5.3
    private static let cycleDuration = inhaleDuration + topUpDuration + exhaleDuration

    let id: ID
    let phaseElapsed: TimeInterval

    init(elapsed: TimeInterval) {
        let position = elapsed.truncatingRemainder(dividingBy: Self.cycleDuration)
        if position < Self.inhaleDuration {
            id = .inhale
            phaseElapsed = position
        } else if position < Self.inhaleDuration + Self.topUpDuration {
            id = .topUp
            phaseElapsed = position - Self.inhaleDuration
        } else {
            id = .exhale
            phaseElapsed = position - Self.inhaleDuration - Self.topUpDuration
        }
    }

    var title: String {
        switch id {
        case .inhale: return "Inhale"
        case .topUp: return "Top up"
        case .exhale: return "Long exhale"
        }
    }

    var subtitle: String {
        switch id {
        case .inhale: return "Fill the lungs gently"
        case .topUp: return "Tiny second sip of air"
        case .exhale: return "Let the body drop"
        }
    }

    var tint: Color {
        switch id {
        case .inhale: return Theme.cool
        case .topUp: return Theme.amber
        case .exhale: return Theme.mint
        }
    }

    var phaseDuration: TimeInterval {
        switch id {
        case .inhale: return Self.inhaleDuration
        case .topUp: return Self.topUpDuration
        case .exhale: return Self.exhaleDuration
        }
    }

    var phaseProgress: Double {
        min(1, max(0, phaseElapsed / phaseDuration))
    }

    var breathFill: Double {
        switch id {
        case .inhale:
            return 0.25 + phaseProgress * 0.55
        case .topUp:
            return 0.80 + phaseProgress * 0.20
        case .exhale:
            return 1.0 - phaseProgress * 0.76
        }
    }

    var lungScale: Double {
        0.82 + breathFill * 0.34
    }

    var mascotOffset: CGFloat {
        CGFloat(-18 + breathFill * 24)
    }

    var rotation: Double {
        switch id {
        case .inhale: return phaseProgress * 8
        case .topUp: return 8 + phaseProgress * 6
        case .exhale: return 14 - phaseProgress * 20
        }
    }

    var secondsRemaining: Int {
        max(1, Int((phaseDuration - phaseElapsed).rounded(.up)))
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
            icon: "hand.raised.fill",
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
