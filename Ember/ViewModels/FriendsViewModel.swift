import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published private(set) var friends: [FriendProfile] = []
    @Published private(set) var incomingRequests: [IncomingFriendRequest] = []
    @Published private(set) var isLoadingFriends = false
    @Published private(set) var isLoadingRequests = false
    @Published private(set) var isSendingRequest = false
    @Published private(set) var respondingRequestIDs: Set<UUID> = []
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let service = FriendService()
    private var feedbackDismissTask: Task<Void, Never>?

    func loadFriends() async {
        guard !isLoadingFriends else { return }
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        do {
            friends = try await service.loadFriends()
        } catch {
            present(error)
        }
    }

    func loadIncomingRequests() async {
        guard !isLoadingRequests else { return }
        isLoadingRequests = true
        defer { isLoadingRequests = false }
        do {
            incomingRequests = try await service.loadIncomingRequests()
        } catch {
            present(error)
        }
    }

    func refreshAll() async {
        async let friendsTask: Void = loadFriends()
        async let requestsTask: Void = loadIncomingRequests()
        _ = await (friendsTask, requestsTask)
    }

    func sendFriendRequest(email: String) async -> Bool {
        guard !isSendingRequest else { return false }
        clearMessages()
        isSendingRequest = true
        defer { isSendingRequest = false }
        do {
            let response = try await service.sendFriendRequest(email: email)
            showSuccess(response.message ?? "Friend request updated.")
            return true
        } catch {
            present(error)
            return false
        }
    }

    func acceptRequest(_ request: IncomingFriendRequest) async {
        await respond(to: request, accept: true)
    }

    func rejectRequest(_ request: IncomingFriendRequest) async {
        await respond(to: request, accept: false)
    }

    private func respond(to request: IncomingFriendRequest, accept: Bool) async {
        guard !respondingRequestIDs.contains(request.id) else { return }
        clearMessages()
        respondingRequestIDs.insert(request.id)
        defer { respondingRequestIDs.remove(request.id) }
        do {
            let response = try await service.respondToRequest(requestID: request.id, accept: accept)
            incomingRequests.removeAll { $0.id == request.id }
            showSuccess(response.message ?? "Friend request updated.")
            if accept { await loadFriends() }
        } catch {
            present(error)
        }
    }

    func clearFeedback() {
        feedbackDismissTask?.cancel()
        successMessage = nil
        errorMessage = nil
    }

    private func clearMessages() {
        clearFeedback()
    }

    private func showSuccess(_ message: String) {
        successMessage = message
        errorMessage = nil
        dismissFeedbackAfterDelay()
    }

    private func present(_ error: Error) {
        #if DEBUG
        debugPrint("Friend RPC error:", error)
        #endif
        let text = error.localizedDescription.lowercased()
        if text.contains("network") || text.contains("internet") {
            errorMessage = "Network unavailable. Please try again."
        } else if text.contains("jwt") || text.contains("session") || text.contains("unauthorized") {
            errorMessage = "Your session has expired. Please sign in again."
        } else if text.contains("function") && text.contains("not found") {
            errorMessage = "Friend features are not available yet."
        } else if text.contains("permission") || text.contains("row-level") || text.contains("rls") {
            errorMessage = "You do not have permission to perform this action."
        } else {
            errorMessage = error.localizedDescription.isEmpty ? "Something went wrong. Please try again." : error.localizedDescription
        }
        dismissFeedbackAfterDelay()
    }

    private func dismissFeedbackAfterDelay() {
        feedbackDismissTask?.cancel()
        feedbackDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.successMessage = nil
            self?.errorMessage = nil
        }
    }
}
