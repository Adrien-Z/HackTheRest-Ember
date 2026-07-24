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
