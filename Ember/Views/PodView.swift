import SwiftUI

struct PodView: View {
    @EnvironmentObject var store: DataStore

    var latestWeek: PodWeek? { store.pod.weeks.max(by: { $0.weekStart < $1.weekStart }) }

    var body: some View {
        ZStack {
                NightBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        SectionHeader(title: "This week",
                                      subtitle: "Goal: \(store.pod.weeklyGoalNights) nights on target, everyone.")
                        ForEach(store.pod.members) { m in PodMemberRow(member: m, goal: store.pod.weeklyGoalNights) }
                        rewardCard
                        privacyNote
                    }
                    .padding()
                }
            }
            .navigationTitle(store.pod.name)
            .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Accountability pod", systemImage: "person.3.fill").font(.headline)
                Spacer()
                Tag(text: "sample", color: Theme.amber)
            }
            Text("Rest better together. When everyone hits their goal, the whole pod unlocks a Blue Box reward.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Social data has no on-device source, so the Pod always shows sample content.")
                .font(.caption2).foregroundStyle(.secondary)
        }.emberCard()
    }

    private var rewardCard: some View {
        Group {
            if let w = latestWeek {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: w.rewardUnlocked ? "gift.fill" : "gift").foregroundStyle(Theme.ember).font(.title3)
                        Text(w.rewardUnlocked ? "Reward unlocked!" : "Reward locked").font(.headline)
                        Spacer()
                        Text("\(w.membersHit)/\(store.pod.members.count) hit")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    if w.rewardUnlocked, let r = w.reward {
                        HStack {
                            Text(r).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ember)
                            Spacer()
                            if w.redeemed { Tag(text: "redeemed", color: Theme.mint) }
                            else { Text("Redeem").font(.caption.weight(.bold)).foregroundStyle(Theme.ember) }
                        }
                        .padding(10)
                        .background(Theme.ember.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("All \(store.pod.members.count) members must reach the weekly goal to unlock.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .emberCard()
            }
        }
    }

    private var privacyNote: some View {
        ScienceNote(text: "Privacy first: your pod sees only a status ring — hit, partial, or miss — never your bedtime, wake time, or raw sleep data. No leaderboards, to avoid sleep-performance anxiety (orthosomnia).", icon: "lock.shield.fill")
    }
}

struct PodMemberRow: View {
    let member: PodMember
    let goal: Int
    var statusColor: Color {
        switch member.status { case "hit": return Theme.mint; case "partial": return Theme.amber; default: return .secondary }
    }
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 5).frame(width: 44, height: 44)
                Circle().trim(from: 0, to: min(1, Double(member.nightsHit)/Double(goal)))
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 44, height: 44)
                Text("\(member.nightsHit)").font(.subheadline.weight(.bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name).font(.subheadline.weight(.semibold))
                Text("\(member.nightsHit)/\(goal) nights · \(member.streakWeeks)-wk streak")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Tag(text: member.status, color: statusColor)
        }
        .emberCard(12)
    }
}
