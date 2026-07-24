import SwiftUI

/// First-run onboarding: a bold, paged introduction that sets up the user's
/// name, morning prep time, and all four permissions (Health, Calendar, Alarm,
/// Notifications) while explaining EMBER's philosophy — a coach, not a tracker.
struct OnboardingView: View {
    var onFinish: () -> Void

    @EnvironmentObject var store: DataStore
    @EnvironmentObject var health: HealthManager
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var wakeAlarm: WakeAlarmService
    @EnvironmentObject var sleepClimate: SleepClimateService
    @EnvironmentObject var auth: AuthViewModel

    @State private var page = 0

    // Local mirrors of permission state so checkmarks animate immediately.
    @State private var healthGranted = false
    @State private var calendarGranted = false
    @State private var climateGranted = false
    @State private var alarmGranted = false
    @State private var notifGranted = false

    private let lastPage = 7

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24).padding(.top, 12)

                ZStack {
                    switch page {
                    case 0: welcome
                    case 1: accountPage
                    case 2: philosophy
                    case 3: healthPage
                    case 4: calendarPage
                    case 5: climatePage
                    case 6: alarmPage
                    default: readyPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
                .id(page)

                footer
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Chrome

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(Theme.emberGradient)
                    .frame(width: geo.size.width * CGFloat(page + 1) / CGFloat(lastPage + 1))
            }
        }
        .frame(height: 5)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Button(action: advance) {
                Text(primaryLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.emberGradient, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }

            if page > 0 && page < lastPage {
                Button("Back") { withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { page -= 1 } }
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 20)
    }

    private var primaryLabel: String {
        switch page {
        case 0: return "Begin"
        case lastPage: return "Enter EMBER"
        case 3, 4, 5, 6: return anyGranted(for: page) ? "Continue" : "Maybe later"
        default: return "Continue"
        }
    }

    private func anyGranted(for p: Int) -> Bool {
        switch p {
        case 3: return healthGranted
        case 4: return calendarGranted
        case 5: return climateGranted
        case 6: return alarmGranted || notifGranted
        default: return true
        }
    }

    private func advance() {
        Haptics.light()
        if page >= lastPage { finish(); return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { page += 1 }
    }

    private func finish() {
        store.persistSettings()
        Haptics.success()
        Task {
            // A connected Health account means the user wants their own data.
            if health.authorized { await store.setMode(.live, health: health, calendar: calendar) }
            onFinish()
        }
    }

    // MARK: - Pages

    private var welcome: some View {
        OnboardScaffold {
            EmberHero()
            OnboardTitle("Sleep is a skill.\nWe coach it.")
            OnboardBody("EMBER isn't another tracker that shows you charts and shrugs. It's a rest coach that actively tunes your nights — grounded in the latest sleep science, personalized to you.")
        }
    }

    private var accountPage: some View {
        OnboardScaffold {
            OnboardGlyph("hand.wave.fill")
            OnboardTitle("Hello,\n\(auth.displayName)")
            Text(auth.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ember.opacity(0.4), lineWidth: 1))
                .padding(.horizontal, 8)
            OnboardBody("We'll use your account display name to personalize Ember.")
        }
    }

    private var philosophy: some View {
        OnboardScaffold {
            OnboardGlyph("gauge.with.dots.needle.bottom.50percent")
            OnboardTitle("Two rest engines,\ntuned to you.")
            OnboardBody("EMBER runs evidence-based protocols and adapts them from your own data every week. Built from sleep science, shaped by warmth rituals.")
            VStack(spacing: 12) {
                EngineBullet(icon: "thermometer.sun.fill", tint: Theme.ember,
                             title: "Thermal Wind-Down",
                             text: "Times a foot bath, warm towel, or other warming ritual to support the core-temperature drop before sleep.")
                EngineBullet(icon: "bed.double.fill", tint: Theme.cool,
                             title: "Sleep Efficiency (CBT-I)",
                             text: "The gold-standard therapy for insomnia — consolidates broken sleep, then widens it.")
            }
            OnboardBody("Whether you take an hour to drift off or wrestle with insomnia, the plan learns and adjusts to fit you.")
        }
    }

    private var healthPage: some View {
        OnboardScaffold {
            OnboardGlyph("heart.fill", tint: .pink)
            OnboardTitle("Learn from your\nreal sleep.")
            OnboardBody("EMBER reads your sleep from Apple Health — no manual logging. Your data stays on your device; we never upload your nights.")
            PermissionButton(title: "Connect Apple Health", tint: .pink, granted: healthGranted) {
                await health.requestAuthorization()
                healthGranted = health.authorized
                return healthGranted
            }
        }
    }

    private var calendarPage: some View {
        OnboardScaffold {
            OnboardGlyph("calendar", tint: Theme.ember)
            OnboardTitle("Never wonder when\nto sleep again.")
            OnboardBody("EMBER reads your calendar and does the math for you — early flight, late meeting, time-zone hop. It shifts tonight's wind-down and wake time automatically, so you can stop planning your sleep and just live.")
            VStack(spacing: 6) {
                Text("How long do you need in the morning?")
                    .font(.subheadline.weight(.semibold))
                Text("From alarm to out-the-door — we protect this before any early start.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                PrepStepper(minutes: $wakeAlarm.prepBufferMin)
                    .padding(.top, 4)
            }
            .padding(.vertical, 8)
            PermissionButton(title: "Connect Calendar", tint: Theme.ember, granted: calendarGranted) {
                await calendar.requestAccess()
                calendarGranted = calendar.isAuthorized
                return calendarGranted
            }
        }
    }

    private var climatePage: some View {
        OnboardScaffold {
            OnboardGlyph("thermometer.medium", tint: Theme.cool)
            OnboardTitle("Plan around\ntonight's room climate.")
            OnboardBody("EMBER can use your approximate location to check overnight heat and humidity. Weather only changes practical wind-down advice — it does not diagnose you or move your circadian rhythm.")
            PermissionButton(title: "Check Sleep Climate", tint: Theme.cool, granted: climateGranted) {
                await sleepClimate.refresh(store: store)
                climateGranted = store.sleepClimate != nil
                return climateGranted
            }
            if let err = sleepClimate.lastError {
                Text(err).font(.caption2).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var alarmPage: some View {
        OnboardScaffold {
            OnboardGlyph("alarm.fill", tint: Theme.amber)
            OnboardTitle("Wake on time,\nevery time.")
            OnboardBody("EMBER sets a real wake alarm from your plan and can quietly move it earlier before an early start — always telling you why. Allow alarms and notifications so it can look after your mornings.")
            VStack(spacing: 10) {
                PermissionButton(title: "Allow Alarms", tint: Theme.amber, granted: alarmGranted) {
                    let ok = await wakeAlarm.requestAlarmAccess()
                    alarmGranted = ok
                    return ok
                }
                PermissionButton(title: "Allow Notifications", tint: Theme.cool, granted: notifGranted) {
                    let ok = await wakeAlarm.requestNotificationAccess()
                    notifGranted = ok
                    return ok
                }
            }
        }
    }

    private var readyPage: some View {
        OnboardScaffold {
            EmberHero()
            OnboardTitle(store.displayName.isEmpty || store.displayName == "You"
                         ? "You're all set." : "You're all set,\n\(store.displayName).")
            OnboardBody("Tonight, EMBER starts learning your rhythm. Every week your plan gets a little more you.\n\nSleep well.")
        }
    }
}
// MARK: - Building blocks

/// Consistent page layout: content is centered, staggered-in on appear.
private struct OnboardScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var appeared = false
    var body: some View {
        ScrollView {
            VStack(spacing: 18) { content }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28).padding(.top, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) { appeared = true }
        }
    }
}

private struct OnboardTitle: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .lineSpacing(2)
    }
}

private struct OnboardBody: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A large ringed glyph with a soft glow.
private struct OnboardGlyph: View {
    let name: String
    var tint: Color = Theme.ember
    init(_ name: String, tint: Color = Theme.ember) { self.name = name; self.tint = tint }
    @State private var pulse = false
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 120, height: 120)
            .background(Circle().fill(tint.opacity(0.12)))
            .overlay(Circle().stroke(tint.opacity(0.3), lineWidth: 1).scaleEffect(pulse ? 1.15 : 1).opacity(pulse ? 0 : 1))
            .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true } }
            .padding(.bottom, 6)
    }
}

/// The brand hero: a pulsing ember ring used on the first and last pages.
private struct EmberHero: View {
    @State private var glow = false
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Theme.emberGradient, lineWidth: 3)
                    .frame(width: 90 + CGFloat(i) * 44, height: 90 + CGFloat(i) * 44)
                    .opacity(glow ? 0.0 : 0.5 - Double(i) * 0.15)
                    .scaleEffect(glow ? 1.3 : 0.9)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.4), value: glow)
            }
            Circle().fill(Theme.emberGradient).frame(width: 76, height: 76)
                .shadow(color: Theme.ember.opacity(0.7), radius: glow ? 26 : 12)
            Image(systemName: "moon.stars.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
        }
        .frame(height: 180)
        .onAppear { glow = true }
    }
}

private struct EngineBullet: View {
    let icon: String, tint: Color, title: String, text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// A permission button that morphs into a green "granted" state after the OS
/// prompt resolves. The action returns whether permission was granted.
private struct PermissionButton: View {
    let title: String
    var tint: Color = Theme.ember
    let granted: Bool
    let action: () async -> Bool
    @State private var working = false

    var body: some View {
        Button {
            guard !granted, !working else { return }
            working = true
            Task {
                let ok = await action()
                working = false
                if ok { Haptics.success() } else { Haptics.light() }
            }
        } label: {
            HStack(spacing: 8) {
                if working {
                    ProgressView().tint(.white)
                } else if granted {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Connected")
                } else {
                    Text(title)
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background((granted ? Theme.mint : tint).opacity(granted ? 0.2 : 1),
                        in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(granted ? Theme.mint : .white)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.mint.opacity(granted ? 0.6 : 0), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: granted)
        .animation(.easeInOut, value: working)
    }
}

/// A stepper for morning prep minutes, in 5-minute steps with a haptic tick.
private struct PrepStepper: View {
    @Binding var minutes: Int
    var body: some View {
        HStack(spacing: 22) {
            stepButton("minus") { minutes = max(10, minutes - 5); Haptics.tick() }
            VStack(spacing: 0) {
                Text("\(minutes)").font(.system(size: 40, weight: .heavy, design: .rounded)).monospacedDigit()
                Text("minutes").font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 110)
            .contentTransition(.numericText())
            .animation(.snappy, value: minutes)
            stepButton("plus") { minutes = min(180, minutes + 5); Haptics.tick() }
        }
    }
    private func stepButton(_ icon: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Image(systemName: icon).font(.title2.weight(.bold)).foregroundStyle(Theme.ember)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.ember.opacity(0.14)))
        }.buttonStyle(.plain)
    }
}

/// Soft drifting ember/blue blobs behind the onboarding for a living backdrop.
private struct AuroraBackground: View {
    @State private var move = false
    var body: some View {
        ZStack {
            Theme.nightGradient.ignoresSafeArea()
            blob(Theme.ember, size: 320).offset(x: move ? -110 : -140, y: move ? -220 : -180)
            blob(Theme.cool, size: 300).offset(x: move ? 130 : 150, y: move ? 260 : 300)
            blob(Theme.emberDeep, size: 260).offset(x: move ? 120 : 90, y: move ? -260 : -300)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { move.toggle() }
        }
    }
    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).blur(radius: 90).opacity(0.35)
    }
}
