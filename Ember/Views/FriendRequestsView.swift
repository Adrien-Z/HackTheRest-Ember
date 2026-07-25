import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @EnvironmentObject private var store: DataStore

    var body: some View {
        List {
            if viewModel.isLoadingRequests && viewModel.incomingRequests.isEmpty {
                ProgressView().frame(maxWidth: .infinity, alignment: .center).listRowBackground(Color.clear)
            } else if viewModel.incomingRequests.isEmpty {
                FriendsEmptyState(
                    title: "No friend requests",
                    systemImage: "person.badge.clock",
                    message: "New requests will appear here.")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.incomingRequests) { request in
                    requestRow(request)
                }
            }
        }
        .navigationTitle("Friend Requests")
        .task { await viewModel.loadIncomingRequests() }
        .refreshable { await viewModel.loadIncomingRequests() }
    }

    private func requestRow(_ request: IncomingFriendRequest) -> some View {
        let isResponding = viewModel.respondingRequestIDs.contains(request.id)
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                BoxSkinImageView(
                    decoration: decoration(for: request.skinId),
                    size: CGSize(width: 48, height: 44))
                    .frame(width: 48, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.displayName).font(.headline)
                    if let username = request.username, !username.isEmpty {
                        Text("@\(username)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let points = request.points {
                        HStack(spacing: 8) {
                            Label("\(points.formatted()) pts", systemImage: "moon.stars.fill")
                            if let streak = request.currentStreakDays {
                                Label("\(streak)d", systemImage: "flame.fill")
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.boxBlue)
                    }
                    if let date = request.requestedAt?.friendRelativeDate {
                        Text(date).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isResponding { ProgressView() }
            }
            HStack {
                Button("Accept") {
                    Task {
                        await viewModel.acceptRequest(request)
                        await store.refreshBoxSpace()
                    }
                }
                    .buttonStyle(.borderedProminent).tint(Theme.boxBlue)
                Button("Reject", role: .destructive) { Task { await viewModel.rejectRequest(request) } }
                    .buttonStyle(.bordered)
            }
            .disabled(isResponding)
        }
        .padding(.vertical, 4)
    }

    private func decoration(for skinID: String?) -> BoxDecoration? {
        guard let skinID else {
            return BoxSpaceSnapshot.localDecorations.first { $0.id == "classic-blue" }
        }
        return BoxSpaceSnapshot.localDecorations.first { $0.id == skinID }
            ?? BoxSpaceSnapshot.localDecorations.first { $0.id == "classic-blue" }
    }
}

struct FriendsEmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Theme.boxBlue)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }
}
