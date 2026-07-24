import SwiftUI
import Charts

/// Circadian-regularity coaching screen. Leads with the Sleep Regularity Index
/// (Phillips 2017) — the metric behind the mortality finding EMBER cites — then
/// social jetlag and an interactive night-by-night sleep-midpoint chart. The
/// framing is corrective ("here's your lever"), not just a readout.
struct RhythmView: View {
    @EnvironmentObject var store: DataStore

    private var r: SleepScience.RegularityReport { store.regularity }

    var coachQuestion: String {
        if let sri = r.sri {
            return "My Sleep Regularity Index is \(Int(sri)) out of 100. What does that mean and how do I raise it?"
        }
        return "How does keeping a regular sleep schedule improve my health?"
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 18) {
                    if r.nights < 2 {
                        ScienceNote(text: "Need a few nights of sleep data to measure your rhythm. Connect Apple Health in Settings (or switch to Sample data).",
                                    icon: "heart.text.square")
                    } else {
                        sriCard
                        AskCoachLink(question: coachQuestion)
                        statsCard
                        midpointCard
                        coaching
                    }
                    ScienceNote(text: "Regularity is the strongest modifiable sleep-health lever — in a ~60,000-person UK Biobank study it predicted mortality more strongly than how long people slept (Windred 2024). The Sleep Regularity Index quantifies it (Phillips 2017).")
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Your Rhythm")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - SRI ring

    private var sriCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Sleep Regularity Index", systemImage: "waveform.path.ecg").font(.headline)
                Spacer()
                Tag(text: sriBand.label, color: sriBand.color)
            }
            SRIRingView(value: r.sri ?? 0)
            Text(sriBand.blurb).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .emberCard()
    }

    private var sriBand: (label: String, color: Color, blurb: String) {
        switch r.sri ?? 0 {
        case 80...:    return ("very regular", Theme.mint,
            "Your sleep/wake timing is highly consistent day to day — the single biggest lever for circadian health, and you're pulling it well.")
        case 60..<80:  return ("fairly regular", Theme.amber,
            "Reasonably consistent, with room to tighten. Anchoring your wake time — even on weekends — is the fastest way to climb.")
        default:       return ("irregular", Theme.ember,
            "Your timing swings night to night. A fixed wake time (and protecting it after late nights) would raise this the most.")
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            MetricStat(value: r.avgMidpoint ?? "—", label: "sleep midpoint", color: Theme.cool)
            Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
            MetricStat(value: r.socialJetlagMin.map { "\(Int($0))m" } ?? "—",
                       label: "social jetlag",
                       color: (r.socialJetlagMin ?? 0) >= 60 ? Theme.ember : .primary)
            Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
            MetricStat(value: r.midpointStdevMin.map { "±\(Int($0))m" } ?? "—", label: "night-to-night")
        }
        .emberCard()
    }

    // MARK: - Interactive midpoint chart

    private var midpointCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep midpoint by night").font(.subheadline.weight(.semibold))
            Text("When the middle of your night falls. Flat = regular. Amber points are weekends.")
                .font(.caption2).foregroundStyle(.secondary)
            MidpointChart(points: r.midpoints)
        }
        .emberCard()
    }

    // MARK: - Coaching notes

    @ViewBuilder private var coaching: some View {
        if let sjl = r.socialJetlagMin, sjl >= 60 {
            ScienceNote(
                text: String(format: "Your sleep midpoint lands about %d min later on weekends — 'social jetlag'. A gap of an hour or more repeatedly shifts your clock, so Monday feels like flying west (Wittmann & Roenneberg 2006). Try capping weekend sleep-ins to ~30 min past your weekday wake.", Int(sjl)),
                icon: "arrow.left.arrow.right")
        }
    }
}

// MARK: - SRI ring

/// A circular gauge that sweeps up to the SRI value on appear, with a light
/// haptic when the fill lands.
struct SRIRingView: View {
    let value: Double
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 14)
            Circle()
                .trim(from: 0, to: shown / 100)
                .stroke(Theme.emberGradient,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(shown))")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("of 100").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 168, height: 168)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { shown = value }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { Haptics.light() }
        }
    }
}

// MARK: - Scrubable midpoint chart

/// Night-by-night sleep midpoint with drag-to-inspect. Uses a numeric night
/// index for the x so touch position maps cleanly to the nearest point;
/// scrubbing ticks a selection haptic and reveals a callout.
struct MidpointChart: View {
    let points: [SleepScience.RegularityReport.MidpointPoint]
    @State private var selected: Int? = nil
    @State private var drawn = false

    private var indexed: [(i: Int, hours: Double, weekend: Bool, day: String)] {
        points.enumerated().map { ($0.offset, Double($0.element.minOfDay) / 60,
                                   $0.element.isWeekend, $0.element.day) }
    }

    var body: some View {
        Chart {
            ForEach(indexed, id: \.i) { p in
                LineMark(x: .value("Night", p.i), y: .value("Midpoint", p.hours))
                    .foregroundStyle(Theme.cool.opacity(0.5))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Night", p.i), y: .value("Midpoint", p.hours))
                    .foregroundStyle(p.weekend ? Theme.amber : Theme.ember)
                    .symbolSize(selected == p.i ? 160 : 60)
            }
            if let sel = selected, let p = indexed.first(where: { $0.i == sel }) {
                RuleMark(x: .value("Night", p.i))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .annotation(position: .top, alignment: .center) {
                        VStack(spacing: 1) {
                            Text(clock(p.hours)).font(.caption.weight(.bold)).monospacedDigit()
                            Text(shortDate(p.day)).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(6)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    }
            }
        }
        .frame(height: 200)
        .chartYAxisLabel("midpoint (h)")
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine() } }
        .opacity(drawn ? 1 : 0)
        .scaleEffect(y: drawn ? 1 : 0.85, anchor: .bottom)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let x = drag.location.x - geo[proxy.plotAreaFrame].origin.x
                            guard let raw: Double = proxy.value(atX: x) else { return }
                            let idx = min(max(Int(raw.rounded()), 0), points.count - 1)
                            if idx != selected { selected = idx; Haptics.tick() }
                        }
                        .onEnded { _ in selected = nil })
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { drawn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Haptics.light() }
        }
    }

    private func clock(_ hours: Double) -> String {
        let m = Int((hours * 60).rounded()) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}
