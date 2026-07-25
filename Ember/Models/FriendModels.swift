import Foundation

struct AvatarConfig: Codable, Sendable {
    let body: String?
    let eyes: String?
    let hat: String?
    let accessory: String?
}

struct FriendActionResponse: Decodable, Sendable {
    let status: String
    let message: String?
}

struct MyBoxSpaceRecord: Decodable, Sendable {
    let userId: UUID
    let username: String?
    let displayName: String
    let avatarConfig: AvatarConfig?
    let monthStart: String
    let resetsAt: String
    let points: Int
    let currentStreakDays: Int
    let bestStreakDays: Int
    let rankNumber: Int
    let skinId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarConfig = "avatar_config"
        case monthStart = "month_start"
        case resetsAt = "resets_at"
        case points
        case currentStreakDays = "current_streak_days"
        case bestStreakDays = "best_streak_days"
        case rankNumber = "rank_number"
        case skinId = "skin_id"
    }
}

struct MonthlyLeaderboardRecord: Decodable, Identifiable, Sendable {
    let rankNumber: Int
    let userId: UUID
    let friendshipId: UUID?
    let displayName: String
    let username: String?
    let avatarConfig: AvatarConfig?
    let monthStart: String
    let points: Int
    let currentStreakDays: Int
    let skinId: String
    let isCurrentUser: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case rankNumber = "rank_number"
        case userId = "user_id"
        case friendshipId = "friendship_id"
        case displayName = "display_name"
        case username
        case avatarConfig = "avatar_config"
        case monthStart = "month_start"
        case points
        case currentStreakDays = "current_streak_days"
        case skinId = "skin_id"
        case isCurrentUser = "is_current_user"
    }
}

struct PointAwardResponse: Decodable, Sendable {
    let status: String
    let eventType: String?
    let awardedPoints: Int
    let monthStart: String
    let points: Int
    let skinId: String

    enum CodingKeys: String, CodingKey {
        case status
        case eventType = "event_type"
        case awardedPoints = "awarded_points"
        case monthStart = "month_start"
        case points
        case skinId = "skin_id"
    }
}

struct SkinSelectionResponse: Decodable, Sendable {
    let status: String
    let monthStart: String
    let skinId: String

    enum CodingKeys: String, CodingKey {
        case status
        case monthStart = "month_start"
        case skinId = "skin_id"
    }
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
    let monthStart: String?
    let points: Int
    let currentStreakDays: Int
    let skinId: String?

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarConfig = "avatar_config"
        case friendsSince = "friends_since"
        case monthStart = "month_start"
        case points
        case currentStreakDays = "current_streak_days"
        case skinId = "skin_id"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        friendshipId = try values.decode(UUID.self, forKey: .friendshipId)
        userId = try values.decode(UUID.self, forKey: .userId)
        username = try values.decodeIfPresent(String.self, forKey: .username)
        displayName = try values.decode(String.self, forKey: .displayName)
        avatarConfig = try values.decodeIfPresent(AvatarConfig.self, forKey: .avatarConfig)
        friendsSince = try values.decodeIfPresent(String.self, forKey: .friendsSince)
        monthStart = try values.decodeIfPresent(String.self, forKey: .monthStart)
        points = try values.decodeIfPresent(Int.self, forKey: .points) ?? 0
        currentStreakDays = try values.decodeIfPresent(Int.self, forKey: .currentStreakDays) ?? 0
        skinId = try values.decodeIfPresent(String.self, forKey: .skinId)
    }
}

extension String {
    var friendRelativeDate: String? {
        guard let date = ISO8601DateFormatter().date(from: self) else { return nil }
        return date.formatted(.relative(presentation: .named))
    }
}
