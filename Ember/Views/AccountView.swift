import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Display name", value: auth.displayName)
                    LabeledContent("Email", value: auth.email)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await auth.signOut()
                            dismiss()
                        }
                    }
                    .disabled(auth.isLoading)
                } footer: {
                    Text("Sign in again to continue using Ember.")
                }
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
