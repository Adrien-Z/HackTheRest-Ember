import Foundation

struct AvatarConfig: Codable, Sendable {
    let body: String?
    let eyes: String?
    let hat: String?
    let accessory: String?
}

struct FriendActionResponse: Decodable, Sendable {
    let status: String
    let message: String
}

struct IncomingFriendRequest: Decodable, Identifiable, Sendable {
    let requestId: UUID
    let userId: UUID
    let username: String?
    let displayName: String
    let avatarConfig: AvatarConfig?
    let requestedAt: String?

    var id: UUID { requestId }

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarConfig = "avatar_config"
        case requestedAt = "requested_at"
    }
}

struct FriendProfile: Decodable, Identifiable, Sendable {
    let friendshipId: UUID
    let userId: UUID
    let username: String?
    let displayName: String
    let avatarConfig: AvatarConfig?
    let friendsSince: String?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarConfig = "avatar_config"
        case friendsSince = "friends_since"
    }
}

extension String {
    var friendRelativeDate: String? {
        guard let date = ISO8601DateFormatter().date(from: self) else { return nil }
        return date.formatted(.relative(presentation: .named))
    }
}
