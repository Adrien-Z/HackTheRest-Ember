import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("账户") {
                    LabeledContent("用户名", value: auth.displayName)
                    LabeledContent("邮箱", value: auth.email)
                }

                Section {
                    Button("退出登录", role: .destructive) {
                        Task {
                            await auth.signOut()
                            dismiss()
                        }
                    }
                    .disabled(auth.isLoading)
                } footer: {
                    Text("退出后需要重新登录才能使用 Ember。")
                }
            }
            .navigationTitle("账户设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
