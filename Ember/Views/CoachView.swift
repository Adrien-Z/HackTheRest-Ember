import SwiftUI

struct CoachView: View {
    @EnvironmentObject var store: DataStore
    @State private var draft: String = ""

    let suggestions = [
        "Why did my time-in-bed change?",
        "Why start warming 60 min before bed?",
        "What should I do about my London flight?"
    ]

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.chat) { msg in ChatBubble(message: msg).id(msg.id) }
                        }.padding()
                    }
                    .onChange(of: store.chat.count) { _ in
                        if let last = store.chat.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                suggestionBar
                inputBar
            }
        }
        .navigationTitle("Rest Coach")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button { Task { await send(s) } } label: {
                        Text(s).font(.caption).padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.card, in: Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal)
        }.padding(.bottom, 8)
    }

    private var inputBar: some View {
        HStack {
            TextField("Ask about your plan…", text: $draft)
                .textFieldStyle(.plain).padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            Button { Task { await send(draft) } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(Theme.ember)
            }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }.padding()
    }

    private func send(_ text: String) async {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        store.chat.append(ChatMessage(role: .user, content: t))
        draft = ""
        let reply = await RestCoach.answer(to: t, store: store, adaptations: store.adaptations)
        // Optional delay for realism:
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
        store.chat.append(ChatMessage(role: .coach, content: reply))
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
