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
                    ScienceNote(text: "SRI checks whether you are asleep or awake at the same clock times from one day to the next. 100 = highly repeatable.", icon: "repeat")
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
        ZStack(alignment: .topTrailing) {
            InsightMascot(style: .rhythm, decoration: selectedDecoration, tint: Theme.ember)
                .offset(x: 6, y: 18)
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                HStack {
                    Label("Timing consistency", systemImage: "waveform.path.ecg").font(.headline)
                    Spacer()
                    Tag(text: sriBand.label, color: sriBand.color)
                }
                SRIRingView(value: r.sri ?? 0)
                Text(sriBand.blurb).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .emberCard()
    }

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first {
            $0.id == store.boxSpace.currentUser.decorationID
        }
    }

    private var sriBand: (label: String, color: Color, blurb: String) {
        switch r.sri ?? 0 {
        case 80...:    return ("very regular", Theme.mint,
            "Your clock is landing in the same place most nights.")
        case 60..<80:  return ("fairly regular", Theme.amber,
            "Pretty steady. Wake-time drift is the next lever.")
        default:       return ("irregular", Theme.ember,
            "Your sleep midpoint is moving around too much.")
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            MetricStat(value: r.avgMidpoint ?? "—", label: "midpoint", color: Theme.cool)
            Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
            MetricStat(value: r.socialJetlagMin.map { "\(Int($0))m" } ?? "—",
                       label: "weekend drift",
                       color: (r.socialJetlagMin ?? 0) >= 60 ? Theme.ember : .primary)
            Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
            MetricStat(value: r.midpointStdevMin.map { "±\(Int($0))m" } ?? "—", label: "daily drift")
        }
        .emberCard()
    }

    // MARK: - Interactive midpoint chart

    private var midpointCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Midpoint trail").font(.subheadline.weight(.semibold))
            Text("Flat = regular. Amber = weekend.")
                .font(.caption2).foregroundStyle(.secondary)
            MidpointChart(points: r.midpoints)
        }
        .emberCard()
    }

    // MARK: - Coaching notes

    @ViewBuilder private var coaching: some View {
        if let sjl = r.socialJetlagMin, sjl >= 60 {
            ScienceNote(
                text: String(format: "Weekend midpoint is %d min later. Cap sleep-ins near 30 min to protect Monday.", Int(sjl)),
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
/// scrubbing ticks a selection haptic and updates a stable readout above the
/// plot. The plot domain is fixed so the chart does not jump while dragging.
struct MidpointChart: View {
    let points: [SleepScience.RegularityReport.MidpointPoint]
    @State private var selected: Int? = nil
    @State private var drawn = false

    private var indexed: [(i: Int, hours: Double, weekend: Bool, day: String)] {
        points.enumerated().map { ($0.offset, Double($0.element.minOfDay) / 60,
                                   $0.element.isWeekend, $0.element.day) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RhythmLegendDot(color: Theme.ember, label: "Weeknight")
                RhythmLegendDot(color: Theme.amber, label: "Weekend")
                Spacer()
                Text(selectedLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Chart {
                ForEach(indexed, id: \.i) { p in
                    LineMark(x: .value("Night", p.i), y: .value("Midpoint", p.hours))
                        .foregroundStyle(Theme.cool.opacity(0.5))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Night", p.i), y: .value("Midpoint", p.hours))
                        .foregroundStyle(p.weekend ? Theme.amber : Theme.ember)
                        .symbolSize(selected == p.i ? 84 : 54)
                }
                if let sel = selected {
                    RuleMark(x: .value("Night", sel))
                        .foregroundStyle(Color.white.opacity(0.24))
                }
            }
            .frame(height: 200)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartYAxisLabel("midpoint")
            .chartXAxis {
                AxisMarks(values: axisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.10))
                    AxisValueLabel {
                        if let index = value.as(Int.self), let point = indexed.first(where: { $0.i == index }) {
                            Text(index == indexed.last?.i ? "last" : shortDate(point.day))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.10))
                    AxisValueLabel {
                        if let hour = value.as(Double.self) {
                            Text(clock(hour))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
                            })
                }
            }
            .transaction { transaction in
                transaction.animation = nil
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

    private var selectedLabel: String {
        guard let selected, let point = indexed.first(where: { $0.i == selected }) else {
            return "drag to inspect"
        }
        return "\(shortDate(point.day)) · \(clock(point.hours))"
    }

    private var xDomain: ClosedRange<Int> {
        0...max(1, points.count - 1)
    }

    private var yDomain: ClosedRange<Double> {
        let values = indexed.map(\.hours)
        guard let minValue = values.min(), let maxValue = values.max() else { return 0...10 }
        let lower = max(0, floor(minValue - 1))
        let upper = min(24, ceil(maxValue + 1))
        return lower == upper ? (lower - 1)...(upper + 1) : lower...upper
    }

    private var axisValues: [Int] {
        let count = points.count
        guard count > 1 else { return [0] }
        let step = count > 21 ? 7 : max(1, count / 4)
        var values = Array(stride(from: 0, to: count, by: step))
        if values.last != count - 1 { values.append(count - 1) }
        return values
    }
}

private struct RhythmLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
