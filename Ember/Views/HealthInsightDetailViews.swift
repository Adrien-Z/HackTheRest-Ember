import Charts
import SwiftUI

struct SleepScoreDetailView: View {
    @EnvironmentObject private var store: DataStore
    @State private var selectedNight: Int? = nil

    private var insight: HealthInsightSnapshot? {
        let nights = store.recentHealthNights.sorted { $0.finalWake < $1.finalWake }
        guard let latest = nights.last else { return nil }
        return HealthInsightSnapshot(nights: nights, latest: latest)
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if let insight {
                        InsightHero(
                            title: "Night quality",
                            value: insight.sleepScore,
                            caption: sleepCaption(insight.sleepScore),
                            symbol: "moon.stars.fill",
                            tint: Theme.cool)
                        AskCoachLink(question: "My Sleep Score is \(insight.sleepScore). Which ingredient should I improve first?")
                        FactorGrid(factors: insight.sleepFactors)
                        SleepScoreTrendCard(points: insight.sleepHistory, selected: $selectedNight)
                        compactDefinitions
                    } else {
                        HealthDetailEmptyState(
                            title: "No sleep score yet",
                            message: "Connect Apple Health or switch to Sample data.",
                            icon: "bed.double.fill")
                    }
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Sleep Score")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sleepCaption(_ score: Int) -> String {
        switch score {
        case 82...: return "Deep enough, efficient enough, low friction."
        case 65..<82: return "Usable recovery. One ingredient is probably dragging."
        default: return "Light recovery. Protect tonight's window."
        }
    }

    private var compactDefinitions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Formula", subtitle: nil)
            HStack(spacing: 8) {
                MetricChip(icon: "bed.double.fill", title: "TST", value: "asleep")
                MetricChip(icon: "checkmark.seal.fill", title: "SE", value: "asleep / bed")
                MetricChip(icon: "moon.zzz.fill", title: "WASO", value: "awake")
            }
            ScienceNote(
                text: "Sleep Score is EMBER's transparent composite: total sleep, efficiency, onset, awakenings, and your own HRV baseline when available.",
                icon: "function")
        }
    }
}

struct BodyBatteryDetailView: View {
    @EnvironmentObject private var store: DataStore
    @State private var selectedPoint: Date? = nil

    private var insight: CurrentEnergySnapshot? {
        guard let day = store.todayEnergyDay, !day.buckets.isEmpty else { return nil }
        return CurrentEnergySnapshot(day: day)
    }

    private var recovery: HealthInsightSnapshot? {
        let nights = store.recentHealthNights.sorted { $0.finalWake < $1.finalWake }
        guard let latest = nights.last else { return nil }
        return HealthInsightSnapshot(nights: nights, latest: latest)
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if let insight {
                        InsightHero(
                            title: "Day energy",
                            value: insight.current,
                            caption: insight.trendLabel,
                            symbol: insight.trendIcon,
                            tint: Theme.mint)
                        AskCoachLink(question: "My Body Battery estimate is \(insight.current). How should I pace the rest of today?")
                        EnergyCurveCard(points: insight.points, selected: $selectedPoint)
                        if let recovery {
                            FactorGrid(factors: recovery.bodyFactors)
                        }
                        energyLegend
                    } else {
                        HealthDetailEmptyState(
                            title: "No energy curve yet",
                            message: "Wear Apple Watch today or switch to Sample data.",
                            icon: "bolt.heart.fill")
                    }
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Body Battery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var energyLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "What moves it", subtitle: nil)
            HStack(spacing: 8) {
                MetricChip(icon: "battery.75percent", title: "Charges", value: "sleep/rest")
                MetricChip(icon: "flame.fill", title: "Drains", value: "steps/load")
                MetricChip(icon: "heart.fill", title: "Context", value: "HR/HRV")
            }
            ScienceNote(
                text: "This is a personal trend estimate, not a clinical measurement. Similar days are the useful comparison.",
                icon: "chart.line.uptrend.xyaxis")
        }
    }
}

private struct InsightHero: View {
    let title: String
    let value: Int
    let caption: String
    let symbol: String
    let tint: Color
    @EnvironmentObject private var store: DataStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            InsightMascot(style: mascotStyle, decoration: selectedDecoration, tint: tint)
                .offset(x: 8, y: -12)
                .allowsHitTesting(false)
            HStack(spacing: 18) {
                AnimatedScoreRing(value: value, tint: tint)
                VStack(alignment: .leading, spacing: 8) {
                    Label(title, systemImage: symbol)
                        .font(.headline)
                        .foregroundStyle(tint)
                    Text(caption)
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("0-100")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
            }
        }
        .emberCard()
    }

    private var mascotStyle: InsightMascot.Style {
        title == "Day energy" ? .battery : .blanket
    }

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first {
            $0.id == store.boxSpace.currentUser.decorationID
        }
    }
}

private struct AnimatedScoreRing: View {
    let value: Int
    let tint: Color
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 12)
            Circle()
                .trim(from: 0, to: shown / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(shown.rounded()))")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("score")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(width: 116, height: 116)
        .onAppear {
            guard shown == 0 else { return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) { shown = Double(value) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { Haptics.light() }
        }
    }
}

private struct FactorGrid: View {
    let factors: [HealthInsightFactor]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Ingredients", subtitle: nil)
            ForEach(factors) { factor in
                FactorBar(factor: factor)
            }
        }
        .emberCard()
    }
}

private struct FactorBar: View {
    let factor: HealthInsightFactor
    @State private var fill = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: factor.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(factor.tint)
                    .frame(width: 18)
                Text(factor.label).font(.subheadline.weight(.semibold))
                Spacer()
                Text(factor.value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(factor.tint)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(factor.tint)
                        .frame(width: proxy.size.width * fill)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                fill = Double(max(0, min(100, factor.score))) / 100
            }
        }
    }
}

private struct SleepScoreTrendCard: View {
    let points: [HealthInsightPoint]
    @Binding var selected: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "7-night score", subtitle: selectedLabel)
            Chart {
                RuleMark(y: .value("Strong", 80))
                    .foregroundStyle(Theme.mint.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("strong")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.mint)
                    }
                RuleMark(y: .value("Fair", 65))
                    .foregroundStyle(Theme.amber.opacity(0.38))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("fair")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.amber)
                    }
                ForEach(points) { point in
                    BarMark(x: .value("Night", point.index), y: .value("Score", point.value))
                        .foregroundStyle(barColor(point.value).opacity(selected == nil || selected == point.index ? 1 : 0.38))
                        .cornerRadius(5)
                    PointMark(x: .value("Night", point.index), y: .value("Score", point.value))
                        .foregroundStyle(barColor(point.value))
                        .symbolSize(selected == point.index ? 110 : 32)
                    if selected == point.index {
                        RuleMark(x: .value("Selected", point.index))
                            .foregroundStyle(Color.white.opacity(0.24))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: points.map(\.index)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let index = value.as(Int.self) {
                            Text(index == points.last?.index ? "last" : "\(index + 1)")
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 50, 80, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.10))
                    AxisValueLabel {
                        if let score = value.as(Int.self) {
                            Text("\(score)")
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 190)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                guard let raw: Double = proxy.value(atX: x) else { return }
                                let idx = min(max(Int(raw.rounded()), 0), max(0, points.count - 1))
                                if idx != selected { selected = idx; Haptics.tick() }
                            }
                        )
                }
            }
            .chartReveal()
        }
        .emberCard()
    }

    private func barColor(_ score: Int) -> Color {
        score >= 80 ? Theme.mint : score >= 65 ? Theme.amber : Theme.ember
    }

    private var selectedLabel: String {
        guard let selected, let point = points.first(where: { $0.index == selected }) else {
            return "0-100 scale · 80+ strong · drag to inspect."
        }
        let label = point.index == points.last?.index ? "Last night" : "Night \(point.index + 1)"
        return "\(label): \(point.value)/100"
    }
}

private struct EnergyCurveCard: View {
    let points: [DailyEnergyPoint]
    @Binding var selected: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Today curve", subtitle: selectedLabel)
            Chart(points) { point in
                AreaMark(x: .value("Time", point.time), y: .value("Energy", point.value))
                    .foregroundStyle(LinearGradient(colors: [Theme.mint.opacity(0.34), Theme.cool.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Time", point.time), y: .value("Energy", point.value))
                    .foregroundStyle(Theme.mint)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Time", point.time), y: .value("Energy", point.value))
                    .foregroundStyle(Theme.mint)
                    .symbolSize(selected == point.time ? 110 : 24)
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...100)
            .frame(height: 210)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                guard let date: Date = proxy.value(atX: x),
                                      let nearest = points.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
                                else { return }
                                if nearest.time != selected { selected = nearest.time; Haptics.tick() }
                            }
                            .onEnded { _ in selected = nil })
                }
            }
            .chartReveal()
        }
        .emberCard()
    }

    private var selectedLabel: String {
        guard let selected, let point = points.first(where: { $0.time == selected }) else {
            return "Scrub the line."
        }
        return "\(point.value) at \(point.time.formatted(date: .omitted, time: .shortened))"
    }
}

private struct MetricChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Theme.ember)
            Text(title)
                .font(.caption.weight(.bold))
            Text(value)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct HealthDetailEmptyState: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Theme.cool)
            Text(title).font(.title2.weight(.bold))
            Text(message).font(.footnote).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .emberCard()
    }
}

#if DEBUG
struct HealthInsightDetailPreviews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SleepScoreDetailView()
                .environmentObject(DataStore.preview)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.ember)
        .previewDisplayName("Sleep Score")

        NavigationStack {
            BodyBatteryDetailView()
                .environmentObject(DataStore.preview)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.ember)
        .previewDisplayName("Body Battery")

        NavigationStack {
            RhythmView()
                .environmentObject(DataStore.preview)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.ember)
        .previewDisplayName("Rhythm")
    }
}
#endif
