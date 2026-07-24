import SwiftUI

struct FriendsListView: View {
    @ObservedObject var viewModel: FriendsViewModel

    var body: some View {
        List {
            if viewModel.isLoadingFriends && viewModel.friends.isEmpty {
                ProgressView().frame(maxWidth: .infinity, alignment: .center).listRowBackground(Color.clear)
            } else if viewModel.friends.isEmpty {
                FriendsEmptyState(
                    title: "No friends yet",
                    systemImage: "person.2",
                    message: "Add friends by entering the email connected to their BlueBox account.")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                    NavigationLink {
                        FriendDetailView(friend: friend)
                    } label: {
                        HStack(spacing: 13) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                .frame(width: 20)
                            FriendBoxAvatar(config: friend.avatarConfig)
                                .frame(width: 48, height: 45)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.displayName).font(.headline)
                                if let username = friend.username, !username.isEmpty {
                                    Text("@\(username)").font(.caption).foregroundStyle(.secondary)
                                }
                                if let date = friend.friendsSince?.friendRelativeDate {
                                    Text("Friends since \(date)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .task { await viewModel.loadFriends() }
        .refreshable { await viewModel.loadFriends() }
    }
}

struct FriendDetailView: View {
    let friend: FriendProfile

    var body: some View {
        VStack(spacing: 16) {
            FriendBoxAvatar(config: friend.avatarConfig).frame(width: 94, height: 82)
            Text(friend.displayName).font(.title2.weight(.bold))
            if let username = friend.username, !username.isEmpty {
                Text("@\(username)").foregroundStyle(.secondary)
            }
            if let date = friend.friendsSince?.friendRelativeDate {
                Text("Friends since \(date)").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NightBackground())
        .navigationTitle("Friend")
        .navigationBarTitleDisplayMode(.inline)
    }
}

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
