import SwiftUI
import Charts

struct ThermalView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var wakeAlarm: WakeAlarmService

    private var fallingAsleepLogs: [SleepLog] { store.sleepLogs.filter { $0.solMin != nil } }
    private var measuredFallAsleepLogs: [SleepLog] {
        store.sleepLogs.filter { ($0.solMin ?? 0) > 0.5 }
    }

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first { $0.id == store.boxSpace.currentUser.decorationID }
    }

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
            return "Why is my warm-up timed about \(rx.prescribedOffsetMin) minutes before bed, and how does warming help me fall asleep faster?"
        }
        return "How does a warm-up ritual help me fall asleep faster?"
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    AskCoachLink(question: coachQuestion)
                    if store.sleepLogs.isEmpty {
                        ScienceNote(text: "Connect Apple Health in Settings to learn whether your warm-up is helping you fall asleep faster.",
                                    icon: "heart.text.square")
                    }
                    fallAsleepCard
                    timingPath
                    scienceCard
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Warm-Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            BoxSkinImageView(decoration: selectedDecoration, size: CGSize(width: 76, height: 76))
                .offset(x: 6, y: -12)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Tonight's warm-up", systemImage: "thermometer.sun.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.ember)
                    Text(heroCopy)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 70)
                }
                HStack(spacing: 0) {
                    MetricStat(value: effectiveTonightPlan.map { clock($0.warmingStart) } ?? "--", label: "start", color: Theme.ember)
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: store.currentThermalRx.map { "\($0.durationMin)m" } ?? "12m", label: "ritual")
                    Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                    MetricStat(value: recentFallAsleepText, label: "recent drift")
                }
            }
        }
        .emberCard()
    }

    private var heroCopy: String {
        guard store.currentThermalRx != nil else {
            return "A short warm ritual helps your body cool down afterward, which can make sleep easier to start."
        }
        if store.thermalConverged {
            return "Your timing is steady: keep the warm ritual close to bedtime and let the cool-down do the work."
        }
        return "EMBER is tuning when your warm ritual starts based on how quickly sleep begins afterward."
    }

    private var recentFallAsleepText: String {
        guard let avg = Array(measuredFallAsleepLogs.compactMap { $0.solMin }.suffix(3)).average else { return "--" }
        if avg <= 20 { return "good" }
        return "\(Int(avg.rounded()))m"
    }

    private var fallAsleepCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Falling asleep", subtitle: fallAsleepSubtitle)
                Spacer(minLength: 0)
                if !measuredFallAsleepLogs.isEmpty {
                    Text("20m")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.mint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.mint.opacity(0.15), in: Capsule())
                }
            }
            if fallAsleepPoints.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.ember)
                    Text("No measured fall-asleep time")
                        .font(.subheadline.weight(.semibold))
                    Text("Apple Health is reporting sleep, but not a separate in-bed start. EMBER can still plan tonight; this chart will wake up when that signal appears.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 178)
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Chart {
                    ForEach(fallAsleepPoints) { point in
                        AreaMark(x: .value("Night", point.index), y: .value("Minutes", point.minutes))
                            .foregroundStyle(LinearGradient(colors: [Theme.ember.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Night", point.index), y: .value("Minutes", point.minutes))
                            .foregroundStyle(Theme.ember)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Night", point.index), y: .value("Minutes", point.minutes))
                            .foregroundStyle(point.minutes <= 20 ? Theme.mint : Theme.ember)
                            .symbolSize(22)
                    }
                    RuleMark(y: .value("Comfort", 20))
                        .foregroundStyle(Theme.mint.opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .frame(height: 178)
                .chartYScale(domain: 0...fallAsleepYMax)
                .chartYAxisLabel("minutes")
                .chartXAxis {
                    AxisMarks(values: fallAsleepAxisValues) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisValueLabel {
                            if let index = value.as(Int.self),
                               let point = fallAsleepPoints.first(where: { $0.index == index }) {
                                Text(shortDate(point.date))
                            }
                        }
                    }
                }
                .chartReveal()
            }
        }
        .emberCard()
    }

    private var fallAsleepSubtitle: String {
        fallAsleepPoints.isEmpty
        ? "Needs an in-bed start from Apple Health."
        : "Lower is easier. The green line is the comfort zone."
    }

    private var fallAsleepPoints: [FallAsleepPoint] {
        Array(measuredFallAsleepLogs.suffix(14).enumerated()).compactMap { index, log in
            guard let minutes = log.solMin else { return nil }
            return FallAsleepPoint(index: index, date: log.date, minutes: minutes)
        }
    }

    private var fallAsleepYMax: Double {
        max(25, ((fallAsleepPoints.map(\.minutes).max() ?? 20) + 5).rounded())
    }

    private var fallAsleepAxisValues: [Int] {
        guard let last = fallAsleepPoints.last?.index else { return [] }
        if last <= 0 { return [0] }
        return [0, last]
    }

    private var timingPath: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Timing path", subtitle: "How EMBER has moved your warm-up over time.")
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.prescriptions) { rx in
                            ThermalRxCard(rx: rx, isCurrent: rx.block == store.currentThermalRx?.block)
                                .id(rx.block)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .onAppear {
                    if let current = store.currentThermalRx?.block {
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
            text: "Why warmth? A warm bath or shower about 1-2 hours before bed can shorten the time it takes to fall asleep. EMBER personalizes the timing; it is coaching, not a diagnosis.",
            icon: "book.closed.fill")
    }

    private func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

private struct FallAsleepPoint: Identifiable {
    let index: Int
    let date: String
    let minutes: Double
    var id: Int { index }
}

private struct ThermalRxCard: View {
    let rx: ThermalPrescription
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(isCurrent ? "Now" : "Block \(rx.block)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isCurrent ? .white : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(isCurrent ? Theme.ember : Color.white.opacity(0.06), in: Capsule())
                Spacer()
                Text(actionLabel(rx.action))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(actionColor(rx.action))
            }
            Text("\(rx.prescribedOffsetMin)m")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ember)
            Text("before bed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(shortRationale(rx))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 154, height: 150, alignment: .topLeading)
        .background(Theme.card.opacity(isCurrent ? 0.95 : 0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder((isCurrent ? Theme.ember : Color.white).opacity(isCurrent ? 0.45 : 0.10), lineWidth: 1))
    }

    private func shortRationale(_ rx: ThermalPrescription) -> String {
        if rx.converged { return "This timing is working; keep it steady." }
        if rx.action == "initiation" { return "Starting point while EMBER learns." }
        return "Adjusted from recent fall-asleep speed."
    }

    private func actionLabel(_ action: String) -> String {
        switch action {
        case "hold_converged": return "steady"
        case "continue": return "tuning"
        case "initiation": return "start"
        default: return action.replacingOccurrences(of: "_", with: " ")
        }
    }
}

extension Array where Element == Double {
    var average: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}
