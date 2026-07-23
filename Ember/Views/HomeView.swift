import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var health: HealthManager

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
                        SectionHeader(title: "Your rest engines",
                                      subtitle: "Two evidence-based protocols, adapting to you.")
                        engineCards
                        NavigationLink { CoachView() } label: { coachTeaser }
                            .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
            .navigationTitle("EMBER")
            .navigationBarTitleDisplayMode(.inline)
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
        }
        .emberCard()
        .background(
            RoundedRectangle(cornerRadius: 20).fill(Theme.ember.opacity(0.06))
        )
    }

    private var healthCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill").foregroundStyle(.pink).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health").font(.subheadline.weight(.semibold))
                if let tst = health.lastNightTSTMin {
                    Text("Last night: \(fmtDur(tst)) asleep").font(.footnote).foregroundStyle(.secondary)
                } else if health.authorized {
                    Text("Connected · no sleep recorded last night").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Connect to auto-import your sleep").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !health.authorized {
                Button("Connect") { Task { await health.requestAuthorization() } }
                    .buttonStyle(.borderedProminent).tint(Theme.ember).controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
            }
        }
        .emberCard(14)
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
