import SwiftUI
import Charts

struct ThermalView: View {
    @EnvironmentObject var store: DataStore

    var titrationLogs: [SleepLog] { store.sleepLogs.filter { $0.solMin != nil } }

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
                    MetricStat(value: "\(rx.prescribedOffsetMin)m", label: "offset before bed", color: Theme.ember)
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: "\(rx.durationMin)m", label: rx.warmingMethod)
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: rx.tempBand, label: "temp band")
                }
            }
            if let sol = Array(titrationLogs.compactMap({ $0.solMin }).suffix(3)).average {
                Text(String(format: "Recent median onset ≈ %.0f min (target < 20).", sol))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .emberCard()
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
