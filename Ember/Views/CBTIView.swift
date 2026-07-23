import SwiftUI
import Charts

struct CBTIView: View {
    @EnvironmentObject var store: DataStore

    var coachQuestion: String {
        if let rx = store.currentCBTIRx {
            return "Why is my time-in-bed \(fmtDur(rx.tibMin)) this week, and how does sleep restriction improve my sleep efficiency?"
        }
        return "How does CBT-I sleep restriction improve my sleep efficiency?"
    }

    var body: some View {
        ZStack {
                NightBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        AskCoachLink(question: coachQuestion)
                        if store.cbtiLogs.isEmpty {
                            ScienceNote(text: "No sleep data yet. Connect Apple Health in Settings (or switch to Sample data) to see your sleep efficiency and time-in-bed titration.",
                                        icon: "heart.text.square")
                        }
                        seChart
                        SectionHeader(title: "Weekly prescriptions",
                                      subtitle: "Time-in-bed titrates to your sleep efficiency.")
                        ForEach(store.cbtiPrescriptions) { rx in CBTIRxRow(rx: rx) }
                        ScienceNote(text: "Sleep-restriction therapy consolidates fragmented sleep by matching time-in-bed to actual sleep, then widening once efficiency exceeds 90%. It is a core, guideline-recommended component of CBT-I (AASM).")
                    }
                    .padding()
                }
            }
            .navigationTitle("Sleep Efficiency")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("CBT-I sleep restriction", systemImage: "bed.double.fill").font(.headline)
            if let rx = store.currentCBTIRx {
                HStack(spacing: 0) {
                    MetricStat(value: fmtDur(rx.tibMin), label: "time in bed", color: Theme.cool)
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: rx.bedTime, label: "prescribed bed")
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: rx.wakeTime, label: "fixed wake")
                }
                if let se = rx.avgSePrior {
                    Text(String(format: "Prior-week efficiency %.1f%%.", se)).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .emberCard()
    }

    private var seChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep efficiency").font(.subheadline.weight(.semibold))
            Chart {
                ForEach(store.cbtiLogs) { log in
                    if let se = log.sePct {
                        LineMark(x: .value("Date", shortDate(log.date)), y: .value("SE", se))
                            .foregroundStyle(Theme.cool)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Date", shortDate(log.date)), y: .value("SE", se))
                            .foregroundStyle(LinearGradient(colors: [Theme.cool.opacity(0.35), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                    }
                }
                RuleMark(y: .value("Increase", 90))
                    .foregroundStyle(Theme.mint.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5,4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("increase ≥90%").font(.caption2).foregroundStyle(Theme.mint)
                    }
                RuleMark(y: .value("Restrict", 85))
                    .foregroundStyle(Theme.ember.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3,4]))
            }
            .frame(height: 200)
            .chartYScale(domain: 70...100)
            .chartYAxisLabel("% efficiency")
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
        }
        .emberCard()
    }
}

struct CBTIRxRow: View {
    let rx: CBTIPrescription
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Week \(rx.week)").font(.subheadline.weight(.semibold))
                Text(shortDate(rx.weekStart)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Tag(text: rx.action, color: actionColor(rx.action))
                Text(fmtDur(rx.tibMin)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.cool)
            }
            Text(rx.rationale).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .emberCard(12)
    }
}
