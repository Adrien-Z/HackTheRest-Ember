import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var mascotIndex = 0
    @State private var mascotRevealToken = 0
    @FocusState private var focusedField: Field?

    private static let welcomeMascots = BoxSpaceSnapshot.localDecorations.filter {
        $0.requiredScore == 500
    }

    private enum Field: Hashable {
        case displayName, email, password
    }

    private var activeMascot: BoxDecoration? {
        guard !Self.welcomeMascots.isEmpty else { return nil }
        return Self.welcomeMascots[mascotIndex % Self.welcomeMascots.count]
    }

    var body: some View {
        ZStack {
            NightBackground()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        SkinRevealPreview(
                            decoration: activeMascot,
                            size: CGSize(width: 158, height: 145),
                            revealToken: mascotRevealToken
                        )
                        .frame(width: 210, height: 166)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(activeMascot?.name ?? "Ember") mascot")

                        Text(isRegistering ? "Join Ember" : "Welcome back")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(isRegistering ? "Create an account and start caring for your sleep." : "Sign in to continue your sleep journey.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.64))
                    }

                    VStack(spacing: 13) {
                        if isRegistering {
                            inputField(
                                "Display name",
                                text: $auth.registrationDisplayName,
                                contentType: .nickname,
                                field: .displayName,
                                submitLabel: .next
                            )
                        }
                        inputField(
                            "Email",
                            text: $email,
                            contentType: .emailAddress,
                            keyboardType: .emailAddress,
                            field: .email,
                            submitLabel: .next
                        )

                        SecureField("Password", text: $password)
                            .textContentType(isRegistering ? .newPassword : .password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { submit() }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if let errorMessage = auth.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        Task {
                            if isRegistering {
                                await auth.signUp(email: email, password: password, displayName: auth.registrationDisplayName)
                            } else {
                                await auth.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            }
                            Text(isRegistering ? "Create Account" : "Sign In")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.ember, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(auth.isLoading)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRegistering.toggle()
                            auth.errorMessage = nil
                        }
                    } label: {
                        Text(isRegistering ? "Already have an account? Sign in" : "New to Ember? Create an account")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .disabled(auth.isLoading)

                }
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
                .padding(.top, 36)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .task {
            mascotRevealToken += 1

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 2_800_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled, !Self.welcomeMascots.isEmpty else { return }
                mascotIndex = (mascotIndex + 1) % Self.welcomeMascots.count
                mascotRevealToken += 1
            }
        }
    }

    private func inputField(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType,
        keyboardType: UIKeyboardType = .default,
        field: Field,
        submitLabel: SubmitLabel
    ) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .focused($focusedField, equals: field)
            .submitLabel(submitLabel)
            .onSubmit { advance(from: field) }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
    }

    private func advance(from field: Field) {
        switch field {
        case .displayName:
            focusedField = .email
        case .email:
            focusedField = .password
        case .password:
            submit()
        }
    }

    private func submit() {
        focusedField = nil
        Task {
            if isRegistering {
                await auth.signUp(email: email, password: password, displayName: auth.registrationDisplayName)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }
}
