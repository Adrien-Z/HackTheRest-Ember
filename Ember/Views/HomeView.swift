import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var health: HealthManager
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var wakeAlarm: WakeAlarmService
    @State private var showSettings = false
    @State private var showAccount = false
    @State private var insightPage = 0

    var tonightWarmTime: String {
        // bed time minus current offset
        guard let rx = store.currentThermalRx else { return "—" }
        return offsetTime(from: store.user.targetBedTime, minusMinutes: rx.prescribedOffsetMin)
    }

    var body: some View {
        ZStack {
                NightBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        greeting
                        tonightCard
                        healthInsightCarousel
                        quickToolEntrances
                    }
                    .padding()
                    .lockHorizontal()
                }
            }
            .navigationTitle("EMBER")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAccount = true } label: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                    .accessibilityLabel("Account settings")
                }
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
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
            }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingWord() + ", \(store.user.name)").font(.title2.weight(.bold))
                Text("Let's set up tonight's rest.").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Tag(text: store.isSampleData ? "sample" : "live",
                color: store.isSampleData ? Theme.amber : Theme.mint)
        }
    }

    private var tonightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Tonight's plan", systemImage: "moon.stars.fill").font(.headline)
                Spacer()
                if store.thermalConverged { Tag(text: "dialed in", color: Theme.mint) }
            }
            HStack(spacing: 0) {
                MetricStat(value: tonightWarmTime, label: "start warming", color: Theme.ember)
                Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                MetricStat(value: store.user.targetBedTime, label: "lights out")
                Divider().frame(height: 40).overlay(Color.white.opacity(0.1))
                MetricStat(value: store.user.targetWakeTime, label: "wake")
            }
            if let rx = store.currentThermalRx {
                Text("\(store.user.warmingMethod) · offset \(rx.prescribedOffsetMin) min before bed")
                    .font(.footnote).foregroundStyle(.secondary)
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
                if t != store.user.targetWakeTime {
                    Button("Move to \(store.user.targetWakeTime)") {
                        Task { await wakeAlarm.setWakeAlarm(at: store.user.targetWakeTime) }
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.ember).controlSize(.small)
                }
                Button("Remove") { wakeAlarm.cancelWakeAlarm() }
                    .buttonStyle(.bordered).controlSize(.small)
            } else {
                Text("Wake alarm").font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button("Set for \(store.user.targetWakeTime)") {
                    Task { await wakeAlarm.setWakeAlarm(at: store.user.targetWakeTime) }
                }
                .buttonStyle(.borderedProminent).tint(Theme.ember).controlSize(.small)
            }
        }
    }

    // MARK: - Apple Health insight carousel

    private var healthInsightCarousel: some View {
        VStack(spacing: 10) {
            TabView(selection: $insightPage) {
                sleepScoreCard.tag(0)
                bodyBatteryCard.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 292)

            HStack(spacing: 7) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(index == insightPage ? Theme.ember : Color.white.opacity(0.22))
                        .frame(width: index == insightPage ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: insightPage)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Health insight card \(insightPage + 1) of 2")
        }
        .padding(.top, 2)
    }

    private var quickToolEntrances: some View {
        HStack(spacing: 14) {
            NavigationLink {
                WhiteNoiseView()
            } label: {
                QuickToolCard(
                    title: "Flowing Stream",
                    subtitle: "Gentle water sounds",
                    icon: "water.waves",
                    tint: Theme.cool)
            }
            .buttonStyle(.plain)

            NavigationLink {
                BreathingTrainingView()
            } label: {
                QuickToolCard(
                    title: "Breathing",
                    subtitle: "4 · 4 · 6 reset",
                    icon: "wind",
                    tint: Theme.mint)
            }
            .buttonStyle(.plain)
        }
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
                    InsightPill(icon: "waveform.path.ecg", text: "\(Int(insights.latest.sePct))% efficient")
                    InsightPill(icon: "moon.zzz.fill", text: "\(Int(insights.latest.wasoMin))m awake")
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
            subtitle: "Estimated morning readiness",
            accent: Theme.mint
        ) {
            if let insights = healthInsights {
                scoreHeader(value: insights.bodyBattery, label: "ready for today", tint: Theme.mint)
                InsightTrendChart(points: insights.batteryHistory, tint: Theme.mint)
                HStack(spacing: 8) {
                    InsightPill(icon: "waveform.path.ecg", text: insights.hrvLabel)
                    InsightPill(icon: "heart.fill", text: insights.heartRateLabel)
                    InsightPill(icon: "chart.line.uptrend.xyaxis", text: insights.recoveryLabel)
                }
            } else {
                HealthInsightEmptyState(
                    title: "Waiting for recovery data",
                    message: "Body Battery appears after Apple Health records a night of sleep and recovery data.",
                    icon: "bolt.heart.fill")
            }
        }
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
                           title: "Thermal Wind-Down",
                           blurb: "Times a warming ritual to drop your core temp and shorten how long you take to fall asleep.",
                           metric: store.currentThermalRx.map { "\($0.prescribedOffsetMin) min offset" } ?? "—",
                           tint: Theme.ember)
            }.buttonStyle(.plain)
            NavigationLink { CBTIView() } label: {
                EngineCard(icon: "bed.double.fill",
                           title: "Sleep Efficiency (CBT-I)",
                           blurb: "Restricts time-in-bed to consolidate fragmented sleep, then widens it as efficiency climbs.",
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
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: title == "Sleep Score" ? "moon.stars.fill" : "bolt.heart.fill")
                    .foregroundStyle(accent)
                    .font(.title3)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.20), lineWidth: 0.8)
        )
        // The pager places cards edge to edge by default; keep a visible gutter
        // while swiping so the next card does not visually merge into this one.
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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

private struct HealthInsightPoint: Identifiable {
    let id: String
    let index: Int
    let value: Int
}

/// A transparent, non-medical readiness estimate. Scores are normalized to the
/// person's own recent HRV and heart-rate baseline rather than population data.
private struct HealthInsightSnapshot {
    let latest: NightSample
    let sleepScore: Int
    let bodyBattery: Int
    let sleepHistory: [HealthInsightPoint]
    let batteryHistory: [HealthInsightPoint]
    let hrvLabel: String
    let heartRateLabel: String
    let recoveryLabel: String

    init(nights: [NightSample], latest: NightSample) {
        self.latest = latest
        let recent = Array(nights.suffix(14))
        let baselineNights = Array(recent.dropLast())
        let hrvBaseline = Self.median(baselineNights.compactMap(\.hrvMs))
        let heartRateBaseline = Self.median(baselineNights.compactMap(\.avgHRBpm))

        sleepScore = Self.sleepScore(for: latest, hrvBaseline: hrvBaseline)
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
    }

    private static func sleepScore(for night: NightSample, hrvBaseline: Double?) -> Int {
        var components: [(value: Double, weight: Double)] = [
            (clamp(Double(night.tstMin) / 480 * 100), 0.34),
            (rangeScore(night.sePct, low: 72, high: 94), 0.26),
            (clamp(100 - max(0, night.solMin - 10) * 2.0), 0.16),
            (clamp(100 - Double(night.wasoMin) * 1.25), 0.14)
        ]
        if let hrv = night.hrvMs, let baseline = hrvBaseline, baseline > 0 {
            components.append((rangeScore(hrv / baseline, low: 0.68, high: 1.12), 0.10))
        }
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
