import SwiftUI

struct FriendRequestsView: View {
    @ObservedObject var viewModel: FriendsViewModel

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
                FriendBoxAvatar(config: request.avatarConfig)
                    .scaleEffect(0.78)
                    .frame(width: 42, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.displayName).font(.headline)
                    if let username = request.username, !username.isEmpty {
                        Text("@\(username)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let date = request.requestedAt?.friendRelativeDate {
                        Text(date).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isResponding { ProgressView() }
            }
            HStack {
                Button("Accept") { Task { await viewModel.acceptRequest(request) } }
                    .buttonStyle(.borderedProminent).tint(Theme.boxBlue)
                Button("Reject", role: .destructive) { Task { await viewModel.rejectRequest(request) } }
                    .buttonStyle(.bordered)
            }
            .disabled(isResponding)
        }
        .padding(.vertical, 4)
    }
}

/// Shared compact mascot used by incoming friend-request rows.
struct FriendBoxAvatar: View {
    let config: AvatarConfig?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BlueBoxMascot(isActive: true, isCurrentUser: false)
            if config?.hat != nil {
                Image(systemName: "moon.stars.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.amber)
                    .offset(x: 8, y: -7)
            }
            if config?.accessory != nil {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.cool)
                    .offset(x: 11, y: 17)
            }
        }
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
