import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var health: HealthManager
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var wakeAlarm: WakeAlarmService
    @State private var showSettings = false

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
                        healthCard
                        if store.regularity.sri != nil {
                            NavigationLink { RhythmView() } label: { rhythmCard }
                                .buttonStyle(.plain)
                        }
                        SectionHeader(title: "Your rest engines",
                                      subtitle: "Two evidence-based protocols, adapting to you.")
                        engineCards
                        NavigationLink { CoachView() } label: { coachTeaser }
                            .buttonStyle(.plain)
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
                Toggle(isOn: $wakeAlarm.autoAdaptEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Auto-adjust for early events").font(.footnote)
                        Text("Re-arms nightly and wakes you earlier before early obligations, with a notification explaining why.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .tint(Theme.ember)
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
