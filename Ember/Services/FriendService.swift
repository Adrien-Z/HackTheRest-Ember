import Foundation
import Supabase

enum FriendServiceError: LocalizedError {
    case notSignedIn
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Please sign in before using friend features."
        case .invalidEmail: return "Enter a valid email address."
        }
    }
}

private struct SendFriendRequestParameters: Encodable {
    let targetEmail: String

    enum CodingKeys: String, CodingKey {
        case targetEmail = "target_email"
    }
}

private struct RespondFriendRequestParameters: Encodable {
    let requestId: UUID
    let acceptRequest: Bool

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case acceptRequest = "accept_request"
    }
}

private struct AwardCommunityPointsParameters: Encodable {
    let eventType: String
    let sourceKey: String

    enum CodingKeys: String, CodingKey {
        case eventType = "p_event_type"
        case sourceKey = "p_source_key"
    }
}

private struct SetMonthlySkinParameters: Encodable {
    let skinId: String

    enum CodingKeys: String, CodingKey {
        case skinId = "p_skin_id"
    }
}

private struct SingleRPCResult<Value: Decodable>: Decodable {
    let value: Value

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let direct = try? container.decode(Value.self) {
            value = direct
            return
        }
        let rows = try container.decode([Value].self)
        guard let first = rows.first else {
            throw DecodingError.valueNotFound(
                Value.self,
                .init(codingPath: decoder.codingPath, debugDescription: "RPC returned no rows."))
        }
        value = first
    }
}

struct FriendService {
    private let supabase = SupabaseManager.client

    func sendFriendRequest(email: String) async throws -> FriendActionResponse {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanedEmail.contains("@"), cleanedEmail.contains("."), !cleanedEmail.hasPrefix("@") else {
            throw FriendServiceError.invalidEmail
        }
        try await requireSession()
        return try await supabase
            .rpc("send_friend_request_by_email", params: SendFriendRequestParameters(targetEmail: cleanedEmail))
            .execute()
            .value
    }

    func loadIncomingRequests() async throws -> [IncomingFriendRequest] {
        try await requireSession()
        return try await supabase.rpc("get_incoming_friend_requests").execute().value
    }

    func respondToRequest(requestID: UUID, accept: Bool) async throws -> FriendActionResponse {
        try await requireSession()
        return try await supabase
            .rpc(
                "respond_friend_request",
                params: RespondFriendRequestParameters(requestId: requestID, acceptRequest: accept)
            )
            .execute()
            .value
    }

    func loadFriends() async throws -> [FriendProfile] {
        try await requireSession()
        return try await supabase.rpc("get_my_friends").execute().value
    }

    private func requireSession() async throws {
        guard supabase.auth.currentSession != nil else { throw FriendServiceError.notSignedIn }
        _ = try await supabase.auth.session
    }
}

struct BoxCommunityService {
    private let supabase = SupabaseManager.client

    func loadMyBoxSpace() async throws -> MyBoxSpaceRecord {
        try await requireSession()
        let result: SingleRPCResult<MyBoxSpaceRecord> =
            try await supabase.rpc("get_my_box_space").execute().value
        return result.value
    }

    func loadMonthlyLeaderboard() async throws -> [MonthlyLeaderboardRecord] {
        try await requireSession()
        return try await supabase.rpc("get_friend_monthly_leaderboard").execute().value
    }

    func awardPoints(eventType: String, sourceKey: String) async throws -> PointAwardResponse {
        try await requireSession()
        let result: SingleRPCResult<PointAwardResponse> = try await supabase
            .rpc(
                "award_community_points",
                params: AwardCommunityPointsParameters(eventType: eventType, sourceKey: sourceKey))
            .execute()
            .value
        return result.value
    }

    func setMonthlySkin(id: String) async throws -> SkinSelectionResponse {
        try await requireSession()
        let result: SingleRPCResult<SkinSelectionResponse> = try await supabase
            .rpc("set_monthly_skin", params: SetMonthlySkinParameters(skinId: id))
            .execute()
            .value
        return result.value
    }

    private func requireSession() async throws {
        guard supabase.auth.currentSession != nil else { throw FriendServiceError.notSignedIn }
        _ = try await supabase.auth.session
    }
}
