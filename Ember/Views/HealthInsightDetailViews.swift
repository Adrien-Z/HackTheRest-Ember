import Charts
import SwiftUI

struct SleepScoreDetailView: View {
    @EnvironmentObject private var store: DataStore

    private var insight: HealthInsightSnapshot? {
        let nights = store.recentHealthNights.sorted { $0.finalWake < $1.finalWake }
        guard let latest = nights.last else { return nil }
        return HealthInsightSnapshot(nights: nights, latest: latest)
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 18) {
                    if let insight {
                        scoreHeader(insight.sleepScore)
                        AskCoachLink(question: "My Sleep Score is \(insight.sleepScore) out of 100. Which part of my sleep should I improve first?")
                        breakdown(for: insight.latest)
                        trend(points: insight.sleepHistory)
                        science
                    } else {
                        ScienceNote(
                            text: "Sleep Score needs Apple Health sleep records. Connect Apple Health and switch to Live data to begin.",
                            icon: "heart.text.square")
                    }
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Sleep Score")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scoreHeader(_ score: Int) -> some View {
        VStack(spacing: 8) {
            Text("\(score)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.cool)
            Text(score >= 80 ? "Strong overnight recovery" : score >= 60 ? "A fair night with room to recover" : "A lighter recovery night")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("A transparent estimate based on your sleep duration, efficiency, time awake, time to fall asleep, and—when available—HRV.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .emberCard()
    }

    private func breakdown(for night: NightSample) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: "What shaped last night", subtitle: "Each component is shown separately so the score stays explainable.")
            ScoreFactorRow(label: "Time asleep", value: fmtDur(night.tstMin), detail: "More opportunity for restoration", color: Theme.cool)
            ScoreFactorRow(label: "Sleep efficiency", value: "\(Int(night.sePct))%", detail: "Time asleep while in bed", color: Theme.mint)
            ScoreFactorRow(label: "Time to fall asleep", value: "\(night.solMin)m", detail: "Shorter is generally more restorative", color: Theme.amber)
            ScoreFactorRow(label: "Awake after sleep onset", value: "\(night.wasoMin)m", detail: "Less fragmentation supports continuity", color: Theme.ember)
            if let hrv = night.hrvMs {
                ScoreFactorRow(label: "Overnight HRV", value: "\(Int(hrv)) ms", detail: "Compared with your own recent baseline", color: Theme.cool)
            }
        }
        .emberCard()
    }

    private func trend(points: [HealthInsightPoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent nights", subtitle: "A seven-night context prevents one night from telling the whole story.")
            Chart(points) { point in
                LineMark(x: .value("Night", point.index), y: .value("Score", point.value))
                    .foregroundStyle(Theme.cool)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Night", point.index), y: .value("Score", point.value))
                    .foregroundStyle(Theme.cool).symbolSize(26)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden).chartYScale(domain: 0...100)
            .frame(height: 120)
        }
        .emberCard()
    }

    private var science: some View {
        VStack(spacing: 10) {
            ScienceNote(text: "Sleep continuity matters: frequent or prolonged awakenings reduce sleep efficiency, and regular adequate sleep opportunity supports daytime alertness and recovery.", icon: "bed.double.fill")
            ScienceNote(text: "HRV is interpreted against your own recent values, not a population target. It can be affected by training load, alcohol, illness, stress, medication, and measurement timing.", icon: "waveform.path.ecg")
        }
    }
}

struct BodyBatteryDetailView: View {
    @EnvironmentObject private var store: DataStore

    private var insight: CurrentEnergySnapshot? {
        guard let day = store.todayEnergyDay, !day.buckets.isEmpty else { return nil }
        return CurrentEnergySnapshot(day: day)
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 18) {
                    if let insight {
                        energyHeader(insight)
                        AskCoachLink(question: "My current Body Battery estimate is \(insight.current). What may be driving it today, and how should I pace the rest of my day?")
                        energyChart(insight.points)
                        factorCard
                        science
                    } else {
                        ScienceNote(
                            text: "Body Battery appears after Apple Health receives today’s Apple Watch data. Heart rate, sleep, movement, and active energy make the estimate more useful.",
                            icon: "heart.text.square")
                    }
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Body Battery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func energyHeader(_ insight: CurrentEnergySnapshot) -> some View {
        VStack(spacing: 8) {
            Text("\(insight.current)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.mint)
            Text("Current energy estimate")
                .font(.subheadline.weight(.semibold))
            Label(insight.trendLabel, systemImage: insight.trendIcon)
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.mint)
            Text("EMBER estimates an energy balance from today’s sleep, movement, heart rate, and HRV relative to your personal baseline. It is not a medical measurement.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .emberCard()
    }

    private func energyChart(_ points: [DailyEnergyPoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Today’s energy", subtitle: "From midnight to the most recently recorded hour.")
            Chart(points) { point in
                AreaMark(x: .value("Time", point.time), y: .value("Energy", point.value))
                    .foregroundStyle(LinearGradient(colors: [Theme.mint.opacity(0.32), Theme.mint.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Time", point.time), y: .value("Energy", point.value))
                    .foregroundStyle(Theme.mint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Time", point.time), y: .value("Energy", point.value))
                    .foregroundStyle(Theme.mint).symbolSize(20)
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .chartYAxis(.hidden).chartYScale(domain: 0...100)
            .frame(height: 170)
        }
        .emberCard()
    }

    private var factorCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeader(title: "How the estimate changes", subtitle: "The model uses trends, not a single reading.")
            ScoreFactorRow(label: "Sleep", value: "Charges", detail: "Detected sleep adds energy through the night", color: Theme.mint)
            ScoreFactorRow(label: "Activity", value: "Drains", detail: "Active energy and steps increase the hourly cost", color: Theme.ember)
            ScoreFactorRow(label: "Heart rate", value: "Context", detail: "Higher than your resting baseline adds load", color: Theme.amber)
            ScoreFactorRow(label: "HRV", value: "Context", detail: "Lower than your baseline can indicate less recovery", color: Theme.cool)
        }
        .emberCard()
    }

    private var science: some View {
        VStack(spacing: 10) {
            ScienceNote(text: "This follows the same high-level idea as wearable energy-reserve features: activity and physiological strain draw down energy, while sleep and quiet recovery restore it.", icon: "bolt.heart.fill")
            ScienceNote(text: "The value is most useful as a personal trend. Compare similar days and your own baseline rather than treating a single number as a diagnosis or training prescription.", icon: "chart.line.uptrend.xyaxis")
        }
    }
}

private struct ScoreFactorRow: View {
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }
}
