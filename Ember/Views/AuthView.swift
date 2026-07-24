import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var isRegistering = false
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            NightBackground()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 72)

                    VStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 88, height: 88)
                            .background(Theme.ember, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                        Text(isRegistering ? "加入 Ember" : "欢迎回来")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(isRegistering ? "创建账户，开始照顾你的睡眠。" : "登录后继续你的睡眠旅程。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.64))
                    }

                    VStack(spacing: 13) {
                        if isRegistering {
                            inputField("昵称", text: $displayName, contentType: .nickname)
                        }
                        inputField("邮箱", text: $email, contentType: .emailAddress, keyboardType: .emailAddress)

                        SecureField("密码", text: $password)
                            .textContentType(isRegistering ? .newPassword : .password)
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
                                await auth.signUp(email: email, password: password, displayName: displayName)
                            } else {
                                await auth.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            }
                            Text(isRegistering ? "创建账户" : "登录")
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
                        Text(isRegistering ? "已有账户？去登录" : "还没有账户？创建一个")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .disabled(auth.isLoading)

                    Spacer(minLength: 36)
                }
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func inputField(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
    }
}
