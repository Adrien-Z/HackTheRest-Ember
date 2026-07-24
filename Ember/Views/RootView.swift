import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var store: DataStore
    @State private var showSplash = true
    @State private var appRevealed = false
    @AppStorage("ember.onboarded") private var onboarded = false

    var body: some View {
        Group {
            if auth.isLoading {
                ZStack {
                    NightBackground()
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.ember)
                }
            } else if auth.isAuthenticated {
                authenticatedApp
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.ember)
        .task(id: auth.displayName) {
            guard auth.isAuthenticated else { return }
            store.applyAuthenticatedDisplayName(auth.displayName)
        }
    }

    private var authenticatedApp: some View {
        ZStack {
            RootTabView()
                .scaleEffect(appRevealed ? 1 : 0.88)

            if !onboarded && !showSplash {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        onboarded = true
                    }
                }
                .zIndex(2)
                .transition(.opacity)
            }

            if showSplash {
                SplashView(onReveal: {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                        appRevealed = true
                    }
                }, onFinished: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                })
                .zIndex(1)
                .transition(.opacity)
            }
        }
    }
}
