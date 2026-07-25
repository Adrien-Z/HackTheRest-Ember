import SwiftUI

struct CoachView: View {
    @EnvironmentObject var store: DataStore
    @State private var draft: String = ""
    @State private var thinking = false
    @State private var shouldFollowStreaming = true
    /// Throttle streaming haptics so they feel like a gentle typing pulse, not a buzz.
    @State private var lastStreamHaptic = Date.distantPast

    /// Suggestion chips built from the user's actual plan and calendar — never
    /// hardcoded event names.
    private var suggestions: [String] {
        var items = ["Why did my time-in-bed change?"]
        if let plan = store.tonightPlan, Calendar.current.isDateInToday(plan.day) {
            items.append("Why start warming at \(clock(plan.warmingStart)) tonight?")
        } else if let rx = store.currentThermalRx {
            items.append("Why start warming \(rx.prescribedOffsetMin) min before bed?")
        }
        items.append("Can I drink tea tonight?")
        if let climate = store.sleepClimate, climate.risk != .low {
            items.append("How should I adjust for tonight's heat?")
        }
        for event in store.calendarEvents.prefix(2) {
            items.append("How should I sleep around \"\(event.title)\"?")
        }
        return items
    }

    private var selectedDecoration: BoxDecoration? {
        store.boxSpace.decorations.first {
            $0.id == store.boxSpace.currentUser.decorationID
        }
    }

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if store.chat.isEmpty {
                                coachEmptyState
                            }
                            ForEach(store.chat) { msg in
                                if msg.role == .user {
                                    ChatBubble(message: msg).id(msg.id)
                                } else if !msg.content.isEmpty {
                                    // Coach replies may contain inline generative-UI widgets.
                                    HStack(alignment: .top, spacing: 9) {
                                        coachAvatar
                                        CoachMessageView(message: msg)
                                    }
                                    .id(msg.id)
                                }
                            }
                            if thinking && (store.chat.last?.content.isEmpty ?? true) {
                                HStack {
                                    ProgressView().tint(Theme.ember)
                                    Text("Thinking…").font(.caption).foregroundStyle(Theme.secondaryText)
                                    Spacer()
                                }.padding(.horizontal).id("thinking")
                            }
                            Color.clear.frame(height: 1).id("coachBottom")
                        }.padding().lockHorizontal()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { _ in
                                if thinking { shouldFollowStreaming = false }
                            }
                    )
                    .onChange(of: store.chat.count) { _ in
                        guard shouldFollowStreaming else { return }
                        withAnimation { proxy.scrollTo("coachBottom", anchor: .bottom) }
                    }
                    .onChange(of: store.chat.last?.content) { _ in
                        if shouldFollowStreaming { proxy.scrollTo("coachBottom", anchor: .bottom) }
                        streamHaptic()
                    }
                }
                suggestionBar
                inputBar
            }
        }
        .navigationTitle("Rest Coach")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Auto-send a question routed from another screen ("Ask the coach").
            if let q = store.pendingCoachQuestion {
                store.pendingCoachQuestion = nil
                await send(q)
            }
        }
    }

    private func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private var coachEmptyState: some View {
        VStack(spacing: 8) {
            BoxSkinImageView(
                decoration: selectedDecoration,
                size: CGSize(width: 76, height: 76)
            )
            .padding(.top, 8)
            Text("What should we adjust tonight?")
                .font(.headline)
            Text(emptyStateSubtitle)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private var emptyStateSubtitle: String {
        if let climate = store.sleepClimate, climate.risk != .low {
            return "Your plan, calendar, sleep data, and tonight's heat are ready."
        }
        return "Your plan, calendar, sleep data, and rhythm are ready."
    }

    private var coachAvatar: some View {
        BoxSkinImageView(
            decoration: selectedDecoration,
            size: CGSize(width: 34, height: 34)
        )
        .padding(5)
        .background(Theme.card.opacity(0.7), in: Circle())
        .overlay(Circle().strokeBorder(Theme.ember.opacity(0.18), lineWidth: 0.8))
        .accessibilityHidden(true)
    }

    private var suggestionBar: some View {
        VStack(spacing: 6) {
            if !store.aiConfigured {
                Text("Connect Agenda intelligence in Settings for richer, conversational answers.")
                    .font(.caption2).foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { Task { await send(s) } } label: {
                            Text(s).font(.caption).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Theme.card, in: Capsule())
                        }.buttonStyle(.plain).disabled(thinking)
                    }
                }.padding(.horizontal)
            }
        }.padding(.bottom, 8)
    }

    private var inputBar: some View {
        HStack {
            TextField("Ask about your plan…", text: $draft)
                .textFieldStyle(.plain).padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            Button { Task { await send(draft) } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(Theme.ember)
            }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
        }.padding()
    }

    private func send(_ text: String) async {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !thinking else { return }
        Haptics.light()
        shouldFollowStreaming = true
        store.chat.append(ChatMessage(role: .user, content: t))
        draft = ""
        thinking = true
        await store.streamCoachReply(history: store.chat)
        thinking = false
        Haptics.stream()
    }

    /// A soft pulse as the coach's reply streams in, at most ~12/sec.
    private func streamHaptic() {
        guard thinking, Date().timeIntervalSince(lastStreamHaptic) > 0.08 else { return }
        lastStreamHaptic = Date()
        Haptics.stream()
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            Text(message.content)
                .font(.subheadline)
                .padding(12)
                .background(message.role == .user ? Theme.ember.opacity(0.9) : Theme.card,
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if message.role == .coach { Spacer() }
        }
    }
}
