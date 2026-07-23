import SwiftUI

/// Section header used across screens.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.semibold))
            if let s = subtitle { Text(s).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A pill tag (action / status labels).
struct Tag: View {
    let text: String
    var color: Color = Theme.ember
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Big metric readout.
struct MetricStat: View {
    let value: String
    let label: String
    var color: Color = .primary
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

/// A labeled rationale/science card with an icon.
struct ScienceNote: View {
    let text: String
    var icon: String = "book.closed.fill"
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.ember).font(.subheadline)
            Text(text).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .emberCard(12)
    }
}

/// Reusable screen background.
struct NightBackground: View {
    var body: some View { Theme.nightGradient.ignoresSafeArea() }
}

/// A tappable row that opens the Rest Coach pre-loaded with a question about the
/// current screen. Sets `store.pendingCoachQuestion` and pushes `CoachView`,
/// which auto-sends it on appear.
struct AskCoachLink: View {
    let question: String
    @EnvironmentObject var store: DataStore
    @State private var go = false
    var body: some View {
        Button {
            store.pendingCoachQuestion = question
            go = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill").foregroundStyle(Theme.ember)
                Text("Ask the coach").font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .emberCard(12)
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $go) { CoachView() }
    }
}

func actionColor(_ action: String) -> Color {
    switch action {
    case "increase": return Theme.mint
    case "hold", "hold_converged", "continue": return Theme.amber
    case "decrease", "restrict": return Theme.ember
    default: return .secondary
    }
}
