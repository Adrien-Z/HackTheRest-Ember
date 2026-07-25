import SwiftUI
import Charts

struct CBTIView: View {
    @EnvironmentObject var store: DataStore

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first { $0.id == store.boxSpace.currentUser.decorationID }
    }

    var coachQuestion: String {
        if let rx = store.currentCBTIRx {
            return "Why is my sleep window \(fmtDur(rx.tibMin)) this week, and how does a fixed wake time help sleep feel deeper?"
        }
        return "How does sleep window training improve sleep efficiency?"
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    AskCoachLink(question: coachQuestion)
                    if store.cbtiLogs.isEmpty {
                        ScienceNote(text: "Connect Apple Health in Settings to see how much of your sleep window is actually spent asleep.",
                                    icon: "heart.text.square")
                    }
                    efficiencyCard
                    weeklyPath
                    scienceCard
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Efficiency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            BoxSkinImageView(decoration: selectedDecoration, size: CGSize(width: 78, height: 78))
                .offset(x: 6, y: -12)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Sleep window", systemImage: "bed.double.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.cool)
                    Text(heroCopy)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 72)
                }
                if let rx = store.currentCBTIRx {
                    HStack(spacing: 0) {
                        MetricStat(value: fmtDur(rx.tibMin), label: "in bed", color: Theme.cool)
                        Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                        MetricStat(value: rx.bedTime, label: "bed")
                        Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                        MetricStat(value: rx.wakeTime, label: "wake")
                    }
                }
            }
        }
        .emberCard()
    }

    private var heroCopy: String {
        guard let rx = store.currentCBTIRx else {
            return "EMBER learns the smallest realistic sleep window, then widens it when sleep becomes more solid."
        }
        if let se = rx.avgSePrior {
            if se >= 90 {
                return "Last week looked solid, so your sleep window can gently open up."
            } else if se < 85 {
                return "Sleep looked scattered, so this week protects a tighter window and a steady wake time."
            }
        }
        return "This is not “less sleep.” It is a temporary training window to make time in bed feel more solid."
    }

    private var efficiencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Window fill", subtitle: "How much time in bed was actually asleep.")
                Spacer(minLength: 0)
                Text("90%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.mint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Theme.mint.opacity(0.15), in: Capsule())
            }
            Chart {
                ForEach(store.cbtiLogs) { log in
                    if let se = log.sePct {
                        AreaMark(x: .value("Night", shortDate(log.date)), y: .value("Percent", se))
                            .foregroundStyle(LinearGradient(colors: [Theme.cool.opacity(0.30), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Night", shortDate(log.date)), y: .value("Percent", se))
                            .foregroundStyle(Theme.cool)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Night", shortDate(log.date)), y: .value("Percent", se))
                            .foregroundStyle(se >= 90 ? Theme.mint : (se < 85 ? Theme.ember : Theme.cool))
                            .symbolSize(22)
                    }
                }
                RuleMark(y: .value("Open", 90))
                    .foregroundStyle(Theme.mint.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                RuleMark(y: .value("Tighten", 85))
                    .foregroundStyle(Theme.ember.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            .frame(height: 178)
            .chartYScale(domain: 70...100)
            .chartYAxisLabel("% asleep")
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .chartReveal()
        }
        .emberCard()
    }

    private var weeklyPath: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Weekly path", subtitle: "The current week is centered. Cards show how the sleep window changed.")
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.cbtiPrescriptions) { rx in
                            CBTIWeekCard(rx: rx, isCurrent: rx.week == store.currentCBTIRx?.week)
                                .id(rx.week)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .onAppear {
                    if let current = store.currentCBTIRx?.week {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.snappy) { proxy.scrollTo(current, anchor: .center) }
                        }
                    }
                }
            }
        }
    }

    private var scienceCard: some View {
        ScienceNote(
            text: "Why a sleep window? Evidence-based sleep care uses a steady wake time and a realistic time-in-bed window to make sleep more consolidated, then widens the window once sleep is efficient.",
            icon: "book.closed.fill")
    }
}

private struct CBTIWeekCard: View {
    let rx: CBTIPrescription
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(isCurrent ? "Now" : "Week \(rx.week)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isCurrent ? .white : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(isCurrent ? Theme.cool : Color.white.opacity(0.16), in: Capsule())
                Spacer()
                Text(actionLabel(rx.action))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(actionColor(rx.action))
            }
            Text(fmtDur(rx.tibMin))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.cool)
            Text("\(rx.bedTime)-\(rx.wakeTime)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Text(shortRationale(rx))
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 164, height: 150, alignment: .topLeading)
        .background(Theme.card.opacity(isCurrent ? 0.95 : 0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder((isCurrent ? Theme.cool : Color.white).opacity(isCurrent ? 0.45 : 0.10), lineWidth: 1))
    }

    private func shortRationale(_ rx: CBTIPrescription) -> String {
        guard let se = rx.avgSePrior else { return "Learning your baseline." }
        if se >= 90 { return "Solid sleep, so the window opens." }
        if se < 85 { return "Scattered sleep, so the window tightens." }
        return "Stable week, keep the rhythm."
    }

    private func actionLabel(_ action: String) -> String {
        switch action {
        case "increase": return "open"
        case "restrict": return "tighten"
        case "hold": return "hold"
        case "baseline": return "start"
        default: return action.replacingOccurrences(of: "_", with: " ")
        }
    }
}
