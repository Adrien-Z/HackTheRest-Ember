import SwiftUI

struct AddFriendView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @State private var email = ""
    @FocusState private var emailFieldFocused: Bool

    var body: some View {
        ZStack {
            NightBackground()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Add a Friend")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Enter the exact email connected to their BlueBox account. We won't reveal whether that email has an account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("friend@example.com", text: $email)
                            .focused($emailFieldFocused)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if let message = viewModel.successMessage {
                            Label(message, systemImage: "checkmark.circle.fill")
                                .font(.footnote).foregroundStyle(Theme.mint)
                        }
                        if let message = viewModel.errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote).foregroundStyle(.orange)
                        }

                        Button {
                            Task {
                                if await viewModel.sendFriendRequest(email: email) { email = "" }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if viewModel.isSendingRequest { ProgressView().tint(.white) }
                                Text("Send Request")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .background(Theme.boxGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .id("sendRequest")
                        .disabled(viewModel.isSendingRequest)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: emailFieldFocused) { isFocused in
                    guard isFocused else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo("sendRequest", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Add a Friend")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.clearFeedback()
            emailFieldFocused = true
        }
    }
}
