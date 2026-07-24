import SwiftUI

struct CoachView: View {
    @EnvironmentObject var store: DataStore
    @State private var draft: String = ""
    @State private var thinking = false

    /// Suggestion chips built from the user's actual plan and calendar — never
    /// hardcoded event names.
    private var suggestions: [String] {
        var items = ["Why did my time-in-bed change?"]
        if let rx = store.currentThermalRx {
            items.append("Why start warming \(rx.prescribedOffsetMin) min before bed?")
        }
        for event in store.calendarEvents.prefix(2) {
            items.append("How should I sleep around \"\(event.title)\"?")
        }
        return items
    }

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.chat) { msg in
                                if msg.role == .user {
                                    ChatBubble(message: msg).id(msg.id)
                                } else if !msg.content.isEmpty {
                                    // Coach replies may contain inline generative-UI widgets.
                                    CoachMessageView(message: msg).id(msg.id)
                                }
                            }
                            if thinking && (store.chat.last?.content.isEmpty ?? true) {
                                HStack {
                                    ProgressView().tint(Theme.ember)
                                    Text("Thinking…").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                }.padding(.horizontal).id("thinking")
                            }
                        }.padding()
                    }
                    .onChange(of: store.chat.count) { _ in
                        if let last = store.chat.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onChange(of: store.chat.last?.content) { _ in
                        if let last = store.chat.last { proxy.scrollTo(last.id, anchor: .bottom) }
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

    private var suggestionBar: some View {
        VStack(spacing: 6) {
            if !store.aiConfigured {
                Text("Using the built-in coach. Add an AI key in Settings for richer, conversational answers.")
                    .font(.caption2).foregroundStyle(.secondary)
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
        store.chat.append(ChatMessage(role: .user, content: t))
        draft = ""
        thinking = true
        await store.streamCoachReply(history: store.chat)
        thinking = false
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
