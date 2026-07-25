import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var health: HealthManager
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var wakeAlarm: WakeAlarmService
    @EnvironmentObject var sleepClimate: SleepClimateService
    @State private var showSettings = false
    @State private var showCoach = false
    @State private var insightPage = 0

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

    var tonightWarmTime: String {
        guard let plan = effectiveTonightPlan else { return "—" }
        return clock(plan.warmingStart)
    }

    private var tonightBedTime: String {
        guard let plan = effectiveTonightPlan else { return store.user.targetBedTime }
        return clock(plan.bed)
    }

    private var tonightWakeTime: String {
        guard let plan = effectiveTonightPlan else { return store.user.targetWakeTime }
        return clock(plan.wake)
    }

    var body: some View {
        ZStack {
                NightBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        greeting
                        tonightCard
                        healthInsightCarousel
                    }
                    .padding()
                    .lockHorizontal()
                }
            }
            .navigationTitle("EMBER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(health)
                    .environmentObject(calendar)
                    .environmentObject(wakeAlarm)
                    .environmentObject(sleepClimate)
            }
            .navigationDestination(isPresented: $showCoach) {
                CoachView()
            }
            .task {
                await store.refreshTodayEnergy(health: health)
                await sleepClimate.refreshIfAuthorized(store: store)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    await store.refreshTodayEnergy(health: health)
                }
            }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingWord() + ", \(store.user.name)").font(.title2.weight(.bold))
                Text("Let's set up tonight's rest.").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var tonightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Tonight's plan", systemImage: "moon.stars.fill").font(.headline)
                Spacer()
            }
            HStack(spacing: 0) {
                MetricStat(value: tonightWarmTime, label: "start warming", color: Theme.ember)
                Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                MetricStat(value: tonightBedTime, label: "lights out")
                Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                MetricStat(value: tonightWakeTime, label: "wake")
            }
            if let plan = effectiveTonightPlan {
                Text(tonightPlanSummary(plan))
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.light()
                    showCoach = true
                } label: {
                    Label("Ask Rest Coach", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Theme.ember.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.ember)
            }
            if WakeAlarmService.isSupported {
                Divider().overlay(Color.white.opacity(0.08))
                wakeAlarmRow
                if let err = wakeAlarm.lastError {
                    Text(err).font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .emberCard()
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Theme.ember.opacity(0.06))
        )
    }

    /// Set / move / remove the AlarmKit wake alarm from the plan's wake time.
    @ViewBuilder private var wakeAlarmRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "alarm.fill").foregroundStyle(Theme.amber)
            if let t = wakeAlarm.scheduledTime {
                Text("Wake alarm · \(t)").font(.footnote)
                Spacer()
                if t != tonightWakeTime {
                    Button("Move to \(tonightWakeTime)") {
                        Task { await wakeAlarm.setWakeAlarm(at: tonightWakeTime) }
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.ember).controlSize(.small)
                }
                Button("Remove") { wakeAlarm.cancelWakeAlarm() }
                    .buttonStyle(.bordered).controlSize(.small)
            } else {
                Text("Wake alarm").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button("Set for \(tonightWakeTime)") {
                    Task { await wakeAlarm.setWakeAlarm(at: tonightWakeTime) }
                }
                .buttonStyle(.borderedProminent).tint(Theme.ember).controlSize(.small)
            }
        }
    }

    // MARK: - Apple Health insight carousel

    private var healthInsightCarousel: some View {
        VStack(spacing: 10) {
            TabView(selection: $insightPage) {
                NavigationLink {
                    SleepScoreDetailView()
                } label: {
                    sleepScoreCard
                }
                .buttonStyle(.plain)
                .tag(0)
                .accessibilityHint("Opens your detailed Sleep Score")
                NavigationLink {
                    BodyBatteryDetailView()
                } label: {
                    bodyBatteryCard
                }
                .buttonStyle(.plain)
                .tag(1)
                .accessibilityHint("Opens your detailed Body Battery")
                NavigationLink {
                    RhythmView()
                } label: {
                    rhythmInsightCard
                }
                .buttonStyle(.plain)
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 292)
            .frame(maxWidth: .infinity)

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == insightPage ? Theme.ember : Color.white.opacity(0.22))
                        .frame(width: index == insightPage ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: insightPage)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Health insight card \(insightPage + 1) of 3")
        }
        .padding(.top, 2)
    }

    private var sleepScoreCard: some View {
        HealthInsightCard(
            title: "Sleep Score",
            subtitle: "Your overnight recovery",
            accent: Theme.cool
        ) {
            if let insights = healthInsights {
                scoreHeader(value: insights.sleepScore, label: "out of 100", tint: Theme.cool)
                InsightTrendChart(points: insights.sleepHistory, tint: Theme.cool)
                HStack(spacing: 8) {
                    InsightPill(icon: "bed.double.fill", text: fmtDur(insights.latest.tstMin))
                    InsightPill(icon: "checkmark.seal.fill", text: "\(Int(insights.latest.sePct))%")
                    InsightPill(icon: "arrow.right", text: "night quality")
                }
            } else {
                HealthInsightEmptyState(
                    title: "Waiting for sleep data",
                    message: "Connect Apple Health and switch to Live data to calculate your Sleep Score.",
                    icon: "bed.double.fill")
            }
        }
    }

    private var bodyBatteryCard: some View {
        HealthInsightCard(
            title: "Body Battery",
            subtitle: "Estimated energy right now",
            accent: Theme.mint
        ) {
            if let energy = currentEnergy {
                scoreHeader(value: energy.current, label: "current energy", tint: Theme.mint)
                DailyEnergyChart(points: energy.points, tint: Theme.mint)
                HStack(spacing: 8) {
                    InsightPill(icon: energy.trendIcon, text: energy.trendLabel)
                    InsightPill(icon: "bolt.heart.fill", text: "day estimate")
                    Spacer()
                    Text("Open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                HealthInsightEmptyState(
                    title: "Waiting for today’s data",
                    message: "Wear your Apple Watch and connect Apple Health to build a current energy estimate.",
                    icon: "bolt.heart.fill")
            }
        }
    }

    private var rhythmInsightCard: some View {
        let rhythm = store.regularity
        return HealthInsightCard(
            title: "My Rhythm",
            subtitle: "Your sleep timing consistency",
            accent: Theme.ember
        ) {
            if rhythm.nights < 2 {
                HealthInsightEmptyState(
                    title: "Learning your rhythm",
                    message: "Log a few more nights to see how consistent your sleep timing is.",
                    icon: "waveform.path.ecg")
            } else {
                scoreHeader(value: Int(rhythm.sri ?? 0), label: "timing score", tint: Theme.ember)
                Chart(Array(rhythm.midpoints.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Night", index),
                        y: .value("Midpoint", Double(point.minOfDay) / 60)
                    )
                    .foregroundStyle(Theme.ember)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Night", index),
                        y: .value("Midpoint", Double(point.minOfDay) / 60)
                    )
                    .foregroundStyle(Theme.ember)
                    .symbolSize(20)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 66)
                HStack(spacing: 8) {
                    InsightPill(icon: "moon.fill", text: rhythm.avgMidpoint ?? "—")
                    InsightPill(icon: "arrow.left.arrow.right", text: rhythm.socialJetlagMin.map { "\(Int($0))m jet lag" } ?? "—")
                    Spacer()
                    Label("Open", systemImage: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ember)
                }
            }
        }
        .accessibilityHint("Opens your detailed sleep rhythm")
    }

    private func scoreHeader(value: Int, label: String, tint: Color) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("\(value)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var healthInsights: HealthInsightSnapshot? {
        let nights = store.recentHealthNights.sorted { $0.finalWake < $1.finalWake }
        guard let latest = nights.last else { return nil }
        return HealthInsightSnapshot(nights: nights, latest: latest)
    }

    private var currentEnergy: CurrentEnergySnapshot? {
        guard let day = store.todayEnergyDay, !day.buckets.isEmpty else { return nil }
        return CurrentEnergySnapshot(day: day)
    }

    @ViewBuilder private var healthCard: some View {
        if store.isSampleData {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(Theme.amber).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sample data").font(.subheadline.weight(.semibold))
                    Text("Switch to Live in Settings to use your Apple Health data.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Settings") { showSettings = true }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .emberCard(14)
        } else if !health.authorized {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill").foregroundStyle(.pink).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health").font(.subheadline.weight(.semibold))
                    Text("Connect to auto-import your sleep").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Connect") {
                    Task { await health.requestAuthorization(); await store.refresh(health: health, calendar: calendar) }
                }
                .buttonStyle(.borderedProminent).tint(Theme.ember).controlSize(.small)
            }
            .emberCard(14)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill").foregroundStyle(.pink).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health").font(.subheadline.weight(.semibold))
                        if let tst = store.healthLastNightTST {
                            Text("Last night: \(fmtDur(tst)) asleep").font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text("Connected · no sleep recorded last night").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
                }
                if store.lastNightHR != nil || store.lastNightHRV != nil {
                    Divider().overlay(Color.white.opacity(0.08))
                    HStack(spacing: 0) {
                        if let hr = store.lastNightHR {
                            MetricStat(value: "\(Int(hr))", label: "avg HR (bpm)", color: .pink)
                        }
                        if let hrv = store.lastNightHRV {
                            MetricStat(value: "\(Int(hrv))", label: "HRV (ms)", color: Theme.cool)
                        }
                    }
                }
            }
            .emberCard(14)
        }
    }

    private var engineCards: some View {
        VStack(spacing: 12) {
            NavigationLink { ThermalView() } label: {
                EngineCard(icon: "thermometer.sun.fill",
                           title: "Warm-Up",
                           blurb: "Times a warming ritual to drop your core temp and shorten how long you take to fall asleep.",
                           metric: store.currentThermalRx.map { "\($0.prescribedOffsetMin)m before bed" } ?? "—",
                           tint: Theme.ember)
            }.buttonStyle(.plain)
            NavigationLink { CBTIView() } label: {
                EngineCard(icon: "bed.double.fill",
                           title: "Efficiency",
                           blurb: "Keeps a steady wake time and tunes your sleep window so time in bed feels more solid.",
                           metric: store.currentCBTIRx.map { "\(fmtDur($0.tibMin)) window" } ?? "—",
                           tint: Theme.cool)
            }.buttonStyle(.plain)
        }
    }

    /// Compact regularity teaser: SRI number + a mini midpoint sparkline.
    private var rhythmCard: some View {
        let r = store.regularity
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Your rhythm", systemImage: "waveform.path.ecg").font(.subheadline.weight(.semibold))
                Text("Regularity Index \(Int(r.sri ?? 0))/100").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Chart(Array(r.midpoints.enumerated()), id: \.offset) { i, p in
                LineMark(x: .value("n", i), y: .value("mid", Double(p.minOfDay) / 60))
                    .foregroundStyle(Theme.cool).interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(width: 90, height: 34)
            Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
        }
        .emberCard(14)
    }

    private var coachTeaser: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill").foregroundStyle(Theme.ember)
            VStack(alignment: .leading) {
                Text("Ask your Rest Coach").font(.subheadline.weight(.semibold))
                Text("Why did my plan change this week?").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
        }.emberCard(14)
    }

    private func tonightPlanSummary(_ plan: DayPlan) -> String {
        var first: String
        if plan.sleepLossMin >= 15 {
            let driver = plan.driverTitle.map { "\($0) " } ?? "Your calendar "
            first = "\(driver)compresses your sleep window by about \(fmtDur(plan.sleepLossMin)), so tonight is about protecting the hours that remain."
        } else if let driver = plan.driverTitle {
            first = "\(driver) shapes tonight's timing, but your sleep window still looks intact."
        } else {
            first = "Your calendar leaves enough room for a full night."
        }

        let actualOffset = max(0, Int(plan.bed.timeIntervalSince(plan.warmingStart) / 60))
        var second = "The warm-up is timed to support the temperature drop before bed."
        if let climate = store.sleepClimate, climate.risk == .high {
            second = "Because the night is hot and humid, pre-cool the room and keep the warming ritual short or optional."
        } else if let climate = store.sleepClimate, climate.risk == .moderate {
            second = "Because the night is warm, cool the room first and keep bedding light."
        } else if let rx = store.currentThermalRx, actualOffset != rx.prescribedOffsetMin {
            second = "The warm-up is shifted around your calendar while keeping it close to bedtime."
        }
        return "\(first) \(second)"
    }

    private func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

struct EngineCard: View {
    let icon: String, title: String, blurb: String, metric: String, tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).font(.title2).foregroundStyle(tint)
                Spacer()
                Tag(text: metric, color: tint)
            }
            Text(title).font(.headline)
            Text(blurb).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack { Spacer(); Text("Open").font(.caption.weight(.semibold)).foregroundStyle(tint)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(tint) }
        }
        .emberCard()
    }
}

// MARK: - Today health insight components

private struct HealthInsightCard<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: Color
    @EnvironmentObject private var store: DataStore
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            InsightMascot(style: mascotStyle, decoration: selectedDecoration, tint: accent)
                .offset(x: 8, y: -6)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                content
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.20), lineWidth: 0.8)
        )
        .padding(.vertical, 6)
    }

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first {
            $0.id == store.boxSpace.currentUser.decorationID
        }
    }

    private var mascotStyle: InsightMascot.Style {
        switch title {
        case "Sleep Score": return .blanket
        case "My Rhythm": return .rhythm
        default: return .battery
        }
    }
}

struct InsightMascot: View {
    enum Style { case blanket, battery, rhythm }

    let style: Style
    let decoration: BoxDecoration?
    let tint: Color
    @State private var bob = false

    var body: some View {
        ZStack {
            switch style {
            case .blanket:
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.20))
                    .frame(width: 78, height: 42)
                    .rotationEffect(.degrees(-6))
                    .offset(y: 16)
                BoxSkinImageView(decoration: decoration, size: CGSize(width: 58, height: 58))
                    .scaleEffect(0.92)
                    .offset(y: -2)
                Image(systemName: "moon.zzz.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .offset(x: 28, y: -24)
            case .battery:
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.75), lineWidth: 2)
                    .frame(width: 70, height: 34)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.55))
                            .frame(width: 48, height: 22)
                            .padding(.leading, 6)
                    }
                    .offset(y: 20)
                BoxSkinImageView(decoration: decoration, size: CGSize(width: 56, height: 56))
                    .offset(y: -10)
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .offset(x: 2, y: 19)
            case .rhythm:
                Circle()
                    .strokeBorder(tint.opacity(0.22), lineWidth: 8)
                    .frame(width: 62, height: 62)
                    .offset(y: 4)
                Circle()
                    .trim(from: 0.08, to: 0.70)
                    .stroke(Theme.amber.opacity(0.46), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-28))
                    .offset(y: 4)
                BoxSkinImageView(decoration: decoration, size: CGSize(width: 56, height: 56))
                    .offset(y: -8)
            }
        }
        .frame(width: 92, height: 96)
        .opacity(0.42)
        .offset(y: bob ? -3 : 3)
        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: bob)
        .onAppear { bob = true }
    }
}

private struct InsightTrendChart: View {
    let points: [HealthInsightPoint]
    let tint: Color

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Night", point.index),
                y: .value("Score", point.value)
            )
            .foregroundStyle(
                LinearGradient(colors: [tint.opacity(0.32), tint.opacity(0.01)], startPoint: .top, endPoint: .bottom)
            )
            LineMark(
                x: .value("Night", point.index),
                y: .value("Score", point.value)
            )
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
            PointMark(
                x: .value("Night", point.index),
                y: .value("Score", point.value)
            )
            .foregroundStyle(tint)
            .symbolSize(20)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...100)
        .frame(height: 66)
    }
}

private struct DailyEnergyChart: View {
    let points: [DailyEnergyPoint]
    let tint: Color

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.time),
                y: .value("Energy", point.value)
            )
            .foregroundStyle(
                LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.01)], startPoint: .top, endPoint: .bottom)
            )
            LineMark(
                x: .value("Time", point.time),
                y: .value("Energy", point.value)
            )
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
            PointMark(
                x: .value("Time", point.time),
                y: .value("Energy", point.value)
            )
            .foregroundStyle(tint)
            .symbolSize(16)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour())
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...100)
        .frame(height: 66)
        .accessibilityLabel("Today’s energy timeline")
    }
}

private struct InsightPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

private struct HealthInsightEmptyState: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Spacer(minLength: 8)
            Image(systemName: icon).font(.title2).foregroundStyle(Theme.cool)
            Text(title).font(.title3.weight(.bold))
            Text(message).font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct HealthInsightPoint: Identifiable {
    let id: String
    let index: Int
    let value: Int
}

struct DailyEnergyPoint: Identifiable {
    let time: Date
    let value: Int
    var id: Date { time }
}

struct HealthInsightFactor: Identifiable {
    let id: String
    let label: String
    let value: String
    let score: Int
    let symbol: String
    let tint: Color
}

/// A transparent, non-medical energy balance. It starts each day at a neutral
/// level, charges during detected sleep/rest, and drains with exertion and
/// elevated heart rate relative to the person's own recent baseline.
struct CurrentEnergySnapshot {
    let points: [DailyEnergyPoint]
    let current: Int
    let trendLabel: String
    let trendIcon: String

    init(day: DailyEnergyDay) {
        var level = 42.0
        var builtPoints: [DailyEnergyPoint] = []

        for bucket in day.buckets {
            let durationHours = bucket.asleepMinutes > 0 ? max(0.25, bucket.asleepMinutes / 60) : 1
            let delta: Double
            if bucket.asleepMinutes >= 20 {
                var recharge = 8.0 * durationHours
                if let hrv = bucket.averageHRV, let baseline = day.hrvBaseline, baseline > 0 {
                    recharge += Self.clamp((hrv / baseline - 0.85) * 5, lower: -1.5, upper: 2.5)
                }
                if let hr = bucket.averageHeartRate, let baseline = day.restingHeartRateBaseline, baseline > 0 {
                    recharge += Self.clamp((baseline / hr - 0.90) * 5, lower: -1.5, upper: 2.5)
                }
                delta = recharge
            } else {
                var drain = 1.25
                drain += min(7, bucket.activeEnergyKcal / 18)
                drain += min(4, bucket.steps / 450)
                if let hr = bucket.averageHeartRate, let baseline = day.restingHeartRateBaseline, baseline > 0 {
                    drain += Self.clamp((hr / baseline - 1) * 7, lower: 0, upper: 7)
                }
                if let hrv = bucket.averageHRV, let baseline = day.hrvBaseline, baseline > 0, hrv < baseline {
                    drain += Self.clamp((1 - hrv / baseline) * 5, lower: 0, upper: 3)
                }
                // Quiet, low-heart-rate periods partially restore energy.
                if bucket.activeEnergyKcal < 4, bucket.steps < 120,
                   let hr = bucket.averageHeartRate, let baseline = day.restingHeartRateBaseline,
                   hr <= baseline * 1.05 {
                    drain -= 1.6
                }
                delta = -drain
            }
            level = Self.clamp(level + delta, lower: 5, upper: 100)
            builtPoints.append(DailyEnergyPoint(time: bucket.time, value: Int(level.rounded())))
        }

        points = builtPoints
        current = builtPoints.last?.value ?? Int(level)
        let lastChange = (builtPoints.last?.value ?? current) - (builtPoints.dropLast().last?.value ?? current)
        if lastChange > 1 {
            trendLabel = "+\(lastChange) this hour"
            trendIcon = "arrow.up.right"
        } else if lastChange < -1 {
            trendLabel = "\(lastChange) this hour"
            trendIcon = "arrow.down.right"
        } else {
            trendLabel = "Steady this hour"
            trendIcon = "arrow.right"
        }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

/// A transparent, non-medical readiness estimate. Scores are normalized to the
/// person's own recent HRV and heart-rate baseline rather than population data.
struct HealthInsightSnapshot {
    let latest: NightSample
    let sleepScore: Int
    let bodyBattery: Int
    let sleepHistory: [HealthInsightPoint]
    let batteryHistory: [HealthInsightPoint]
    let sleepFactors: [HealthInsightFactor]
    let bodyFactors: [HealthInsightFactor]
    let hrvLabel: String
    let heartRateLabel: String
    let recoveryLabel: String

    init(nights: [NightSample], latest: NightSample) {
        self.latest = latest
        let recent = Array(nights.suffix(14))
        let baselineNights = Array(recent.dropLast())
        let hrvBaseline = Self.median(baselineNights.compactMap(\.hrvMs))
        let heartRateBaseline = Self.median(baselineNights.compactMap(\.avgHRBpm))

        let latestSleepComponents = Self.sleepComponents(for: latest, hrvBaseline: hrvBaseline)
        sleepScore = Self.weightedScore(latestSleepComponents)
        bodyBattery = Self.bodyBattery(
            sleepScore: sleepScore,
            night: latest,
            hrvBaseline: hrvBaseline,
            heartRateBaseline: heartRateBaseline)

        let trendNights = Array(recent.suffix(7))
        sleepHistory = trendNights.enumerated().map {
            HealthInsightPoint(
                id: "sleep-\($0.element.date)",
                index: $0.offset,
                value: Self.sleepScore(for: $0.element, hrvBaseline: hrvBaseline))
        }
        batteryHistory = trendNights.enumerated().map {
            let score = Self.sleepScore(for: $0.element, hrvBaseline: hrvBaseline)
            return HealthInsightPoint(
                id: "battery-\($0.element.date)",
                index: $0.offset,
                value: Self.bodyBattery(
                    sleepScore: score,
                    night: $0.element,
                    hrvBaseline: hrvBaseline,
                    heartRateBaseline: heartRateBaseline))
        }

        hrvLabel = latest.hrvMs.map { "HRV \(Int($0)) ms" } ?? "HRV unavailable"
        heartRateLabel = latest.avgHRBpm.map { "HR \(Int($0)) bpm" } ?? "HR unavailable"
        recoveryLabel = "\(sleepScore >= 75 ? "well recovered" : "take it easy")"
        sleepFactors = [
            HealthInsightFactor(id: "duration", label: "Duration", value: fmtDur(latest.tstMin), score: Int(latestSleepComponents[0].value.rounded()), symbol: "bed.double.fill", tint: Theme.cool),
            HealthInsightFactor(id: "efficiency", label: "Efficiency", value: "\(Int(latest.sePct.rounded()))%", score: Int(latestSleepComponents[1].value.rounded()), symbol: "checkmark.seal.fill", tint: Theme.mint),
            HealthInsightFactor(id: "onset", label: "Onset", value: "\(Int(latest.solMin.rounded()))m", score: Int(latestSleepComponents[2].value.rounded()), symbol: "timer", tint: Theme.amber),
            HealthInsightFactor(id: "awake", label: "Awake", value: "\(latest.wasoMin)m", score: Int(latestSleepComponents[3].value.rounded()), symbol: "moon.zzz.fill", tint: Theme.ember)
        ] + (latestSleepComponents.count > 4 ? [
            HealthInsightFactor(id: "hrv", label: "HRV", value: latest.hrvMs.map { "\(Int($0)) ms" } ?? "—", score: Int(latestSleepComponents[4].value.rounded()), symbol: "waveform.path.ecg", tint: Theme.cool)
        ] : [])
        bodyFactors = Self.bodyFactors(sleepScore: sleepScore, night: latest, hrvBaseline: hrvBaseline, heartRateBaseline: heartRateBaseline)
    }

    private static func sleepScore(for night: NightSample, hrvBaseline: Double?) -> Int {
        weightedScore(sleepComponents(for: night, hrvBaseline: hrvBaseline))
    }

    private static func sleepComponents(for night: NightSample, hrvBaseline: Double?) -> [(value: Double, weight: Double)] {
        var components: [(value: Double, weight: Double)] = [
            (clamp(Double(night.tstMin) / 480 * 100), 0.34),
            (rangeScore(night.sePct, low: 72, high: 94), 0.26),
            (clamp(100 - max(0, night.solMin - 10) * 2.0), 0.16),
            (clamp(100 - Double(night.wasoMin) * 1.25), 0.14)
        ]
        if let hrv = night.hrvMs, let baseline = hrvBaseline, baseline > 0 {
            components.append((rangeScore(hrv / baseline, low: 0.68, high: 1.12), 0.10))
        }
        return components
    }

    private static func weightedScore(_ components: [(value: Double, weight: Double)]) -> Int {
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        return Int((components.reduce(0) { $0 + $1.value * $1.weight } / totalWeight).rounded())
    }

    private static func bodyBattery(
        sleepScore: Int,
        night: NightSample,
        hrvBaseline: Double?,
        heartRateBaseline: Double?
    ) -> Int {
        var components: [(value: Double, weight: Double)] = [(Double(sleepScore), 0.45)]
        if let hrv = night.hrvMs, let baseline = hrvBaseline, baseline > 0 {
            components.append((rangeScore(hrv / baseline, low: 0.65, high: 1.15), 0.30))
        }
        if let hr = night.avgHRBpm, let baseline = heartRateBaseline, hr > 0 {
            components.append((rangeScore(baseline / hr, low: 0.82, high: 1.12), 0.25))
        }
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        return Int((components.reduce(0) { $0 + $1.value * $1.weight } / totalWeight).rounded())
    }

    private static func bodyFactors(
        sleepScore: Int,
        night: NightSample,
        hrvBaseline: Double?,
        heartRateBaseline: Double?
    ) -> [HealthInsightFactor] {
        var factors = [
            HealthInsightFactor(id: "sleep", label: "Sleep charge", value: "\(sleepScore)", score: sleepScore, symbol: "battery.75percent", tint: Theme.mint)
        ]
        if let hrv = night.hrvMs, let baseline = hrvBaseline, baseline > 0 {
            let score = Int(rangeScore(hrv / baseline, low: 0.65, high: 1.15).rounded())
            factors.append(HealthInsightFactor(id: "hrv", label: "HRV", value: "\(Int(hrv)) ms", score: score, symbol: "waveform.path.ecg", tint: Theme.cool))
        }
        if let hr = night.avgHRBpm, let baseline = heartRateBaseline, hr > 0 {
            let score = Int(rangeScore(baseline / hr, low: 0.82, high: 1.12).rounded())
            factors.append(HealthInsightFactor(id: "hr", label: "Sleep HR", value: "\(Int(hr)) bpm", score: score, symbol: "heart.fill", tint: Theme.amber))
        }
        return factors
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    private static func rangeScore(_ value: Double, low: Double, high: Double) -> Double {
        clamp((value - low) / (high - low) * 100)
    }

    private static func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}
