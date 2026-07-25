import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: DataStore

    func adaptation(for e: CalendarEvent) -> Adaptation? {
        store.adaptations.first { $0.eventId == e.id }
    }
    func icon(for type: String) -> String {
        switch RestAlgorithms.normalizedCategory(type) {
        case "social_jetlag": return "music.note"
        case "timezone_travel": return "airplane"
        case "early_obligation": return "briefcase.fill"
        case "demanding_event": return "bolt.heart"
        default: return "calendar"
        }
    }

    /// Live mode needs the AI configured to categorize; surface a prompt otherwise.
    private var needsAIPrompt: Bool { !store.isSampleData && (!store.aiConfigured || store.aiError != nil) }

    var body: some View {
        ZStack {
                NightBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        intro
                        if needsAIPrompt {
                            ScienceNote(text: store.aiError
                                ?? "Connect Agenda intelligence in Settings to sort calendar events into sleep-relevant patterns like travel, late nights, and early starts.",
                                icon: "sparkles")
                        } else if store.calendarEvents.isEmpty {
                            ScienceNote(text: store.isSampleData
                                ? "No upcoming disruptions in the sample agenda."
                                : "No sleep-relevant events found in your calendar for the last week or next two weeks.",
                                icon: "calendar.badge.checkmark")
                        }
                        ForEach(store.calendarEvents) { e in
                            EventCard(event: e, adaptation: adaptation(for: e), icon: icon(for: e.type))
                        }
                        ScienceNote(text: "The agent protects sleep REGULARITY — the strongest predictor of mortality in a 60,000-person UK Biobank study, ahead of duration (Windred 2024). It watches your calendar and pre-adjusts your plan around disruptions.")
                    }
                    .padding()
                    .lockHorizontal()
                }
            }
            .navigationTitle("Agenda")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Proactive rest agent", systemImage: "sparkles").font(.headline)
            Text("EMBER reads your upcoming events and adapts your rest plan before disruptions happen.")
                .font(.footnote).foregroundStyle(Theme.secondaryText)
        }.emberCard()
    }
}

struct EventCard: View {
    let event: CalendarEvent
    let adaptation: Adaptation?
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundStyle(Theme.ember)
                VStack(alignment: .leading) {
                    Text(event.title).font(.subheadline.weight(.semibold))
                    Text(shortDate(event.startTs)).font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if adaptation?.applied == true { Tag(text: "adapted", color: Theme.mint) }
            }
            if let a = adaptation {
                Divider().overlay(Color.white.opacity(0.08))
                if let why = a.whyItAffectsSleep, !why.isEmpty {
                    Text(why).font(.footnote).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(Theme.ember).font(.caption)
                    Text(a.recommendation).font(.footnote).fixedSize(horizontal: false, vertical: true)
                }
                Text(a.scienceBasis).font(.caption2).foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .emberCard()
    }
}
