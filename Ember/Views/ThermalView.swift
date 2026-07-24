import SwiftUI
import Charts

struct ThermalView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var wakeAlarm: WakeAlarmService

    var titrationLogs: [SleepLog] { store.sleepLogs.filter { $0.solMin != nil } }

    private var effectiveTonightPlan: DayPlan? {
        if let plan = store.tonightPlan, Calendar.current.isDateInToday(plan.day) {
            return plan
        }
        let offset = store.currentThermalRx?.prescribedOffsetMin ?? store.user.currentOffsetMin
        return DayPlanner.build(
            nightOf: Calendar.current.startOfDay(for: Date()),
            user: store.user,
            warmingOffsetMin: offset,
            prepBufferMin: wakeAlarm.prepBufferMin,
            events: store.agendaEvents.filter { !$0.isAllDay })
    }

    var coachQuestion: String {
        if let rx = store.currentThermalRx {
            return "Why is my warming offset \(rx.prescribedOffsetMin) minutes before bed, and how does warming help me fall asleep faster?"
        }
        return "How does my warming wind-down ritual help me fall asleep faster?"
    }

    var body: some View {
        ZStack {
                NightBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        AskCoachLink(question: coachQuestion)
                        if store.sleepLogs.isEmpty {
                            ScienceNote(text: "No sleep data yet. Connect Apple Health in Settings (or switch to Sample data) to see your sleep-onset latency and titration.",
                                        icon: "heart.text.square")
                        }
                        solChart
                        SectionHeader(title: "Titration history",
                                      subtitle: "Each block adapts the warming offset to your sleep-onset latency.")
                        ForEach(store.prescriptions) { rx in ThermalRxRow(rx: rx) }
                        ScienceNote(text: "Passive body heating 1–2 h before bed shortens sleep-onset latency by ~9 min on average (Haghayegh 2019 meta-analysis, 17 studies). EMBER personalizes the exact offset for you.")
                    }
                    .padding()
                    .lockHorizontal()
                }
            }
            .navigationTitle("Thermal Wind-Down")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Warming ritual", systemImage: "thermometer.sun.fill").font(.headline)
                Spacer()
                if store.thermalConverged { Tag(text: "converged", color: Theme.mint) }
            }
            if let rx = store.currentThermalRx {
                HStack(spacing: 0) {
                    MetricStat(value: effectiveTonightPlan.map { clock($0.warmingStart) } ?? "\(rx.prescribedOffsetMin)m",
                               label: effectiveTonightPlan == nil ? "offset before bed" : "tonight start",
                               color: Theme.ember)
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: effectiveTonightPlan.map { clock($0.bed) } ?? "\(rx.durationMin)m",
                               label: effectiveTonightPlan == nil ? rx.warmingMethod : "lights out")
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: "\(rx.prescribedOffsetMin)m", label: "usual offset")
                }
            }
            if let sol = Array(titrationLogs.compactMap({ $0.solMin }).suffix(3)).average {
                Text(String(format: "Recent median onset ≈ %.0f min (target < 20).", sol))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .emberCard()
    }

    private func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private var solChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep-onset latency").font(.subheadline.weight(.semibold))
            Chart {
                ForEach(store.sleepLogs) { log in
                    if let sol = log.solMin {
                        LineMark(x: .value("Date", shortDate(log.date)), y: .value("SOL", sol))
                            .foregroundStyle(Theme.ember)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", shortDate(log.date)), y: .value("SOL", sol))
                            .foregroundStyle(Theme.ember)
                    }
                }
                RuleMark(y: .value("Target", 20))
                    .foregroundStyle(Theme.mint.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5,4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("target 20 min").font(.caption2).foregroundStyle(Theme.mint)
                    }
            }
            .frame(height: 200)
            .chartYAxisLabel("minutes")
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
            .chartReveal()
        }
        .emberCard()
    }
}

struct ThermalRxRow: View {
    let rx: ThermalPrescription
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Block \(rx.block)").font(.subheadline.weight(.semibold))
                Spacer()
                Tag(text: rx.action.replacingOccurrences(of: "_", with: " "), color: actionColor(rx.action))
                Text("\(rx.prescribedOffsetMin)m").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ember)
            }
            Text(rx.rationale).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .emberCard(12)
    }
}

extension Array where Element == Double {
    var average: Double? { isEmpty ? nil : reduce(0,+)/Double(count) }
}
