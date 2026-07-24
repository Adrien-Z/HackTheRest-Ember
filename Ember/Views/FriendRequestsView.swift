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
            HStack(spacing: 13) {
                FriendBoxAvatar(config: request.avatarConfig).frame(width: 48, height: 45)
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
