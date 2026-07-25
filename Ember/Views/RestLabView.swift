import SwiftUI

struct RestLabView: View {
    @EnvironmentObject private var store: DataStore

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first { $0.id == store.boxSpace.currentUser.decorationID }
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    protocolSection
                    helperSection
                }
                .padding()
                .lockHorizontal()
            }
        }
        .navigationTitle("Rest Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        HStack(spacing: 14) {
            BoxSkinImageView(decoration: selectedDecoration, size: CGSize(width: 72, height: 72))
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose the right lever")
                    .font(.title3.weight(.bold))
                Text("Science-backed plans and gentle wind-down tools live here.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .emberCard()
    }

    private var protocolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Build tonight's plan", subtitle: "Personalized protocols that adapt from your data.")
            VStack(spacing: 10) {
                NavigationLink { ThermalView() } label: {
                    RestLabWideCard(
                        title: "Warm-Up",
                        subtitle: "Time your foot bath, shower, or warm towel so the cool-down helps sleep start.",
                        metric: warmMetric,
                        icon: "thermometer.sun.fill",
                        tint: Theme.ember)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

                NavigationLink { CBTIView() } label: {
                    RestLabWideCard(
                        title: "Efficiency",
                        subtitle: "Tune a realistic sleep window so time in bed feels more solid.",
                        metric: efficiencyMetric,
                        icon: "bed.double.fill",
                        tint: Theme.cool)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
            }
        }
    }

    private var helperSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Wind down now", subtitle: "Small tools for the last stretch before bed.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink { WindDownRitualsView() } label: {
                    RestLabSmallCard(
                        title: "Rituals",
                        subtitle: "Warmth, tea, stretch",
                        icon: "hands.sparkles.fill",
                        tint: Theme.ember)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

                NavigationLink { BreathingTrainingView() } label: {
                    RestLabSmallCard(
                        title: "Breathing",
                        subtitle: "4 · 4 · 6 reset",
                        icon: "wind",
                        tint: Theme.mint)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

                NavigationLink { WhiteNoiseView() } label: {
                    RestLabSmallCard(
                        title: "Sounds",
                        subtitle: "Stream, rain, birds",
                        icon: "water.waves",
                        tint: Theme.cool)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
            }
        }
    }

    private var warmMetric: String {
        if let plan = store.tonightPlan, Calendar.current.isDateInToday(plan.day) {
            return plan.warmingStart.formatted(.dateTime.hour().minute())
        }
        return store.currentThermalRx.map { "\($0.prescribedOffsetMin)m before bed" } ?? "ready"
    }

    private var efficiencyMetric: String {
        store.currentCBTIRx.map { fmtDur($0.tibMin) } ?? "learning"
    }
}

private struct RestLabWideCard: View {
    let title: String
    let subtitle: String
    let metric: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(metric)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.14), in: Capsule())
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .background(Theme.card.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(tint.opacity(0.18), lineWidth: 0.8))
    }
}

private struct RestLabSmallCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Spacer(minLength: 6)
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .padding(16)
        .background(Theme.card.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(tint.opacity(0.18), lineWidth: 0.8))
    }
}
