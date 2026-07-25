import SwiftUI

/// Data-source settings. Explicit toggle between live Apple Health data and the
/// bundled sample data (no automatic fallback), plus the permission prompts and
/// the handful of settings used when building live data.
struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var health: HealthManager
    @EnvironmentObject var calendar: CalendarService
    @EnvironmentObject var wakeAlarm: WakeAlarmService
    @EnvironmentObject var sleepClimate: SleepClimateService
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyDraft = ""

    private var modeBinding: Binding<DataSourceMode> {
        Binding(get: { store.mode },
                set: { new in
                    Haptics.tick()
                    Task { await store.setMode(new, health: health, calendar: calendar) }
                })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Data source", selection: modeBinding) {
                        Text("Live · Apple Health").tag(DataSourceMode.live)
                        Text("Sample data").tag(DataSourceMode.sample)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Data source")
                } footer: {
                    Text(store.mode == .live
                         ? "Your sleep charts and prescriptions are derived from Apple Health. Connect the sources below."
                         : "Showing bundled sample data so you can explore the app without granting any permissions.")
                }

                Section {
                    Toggle(isOn: $store.demoEventsEnabled) {
                        Label("Show sample agenda events", systemImage: "calendar.badge.plus")
                    }
                    .tint(Theme.ember)
                    .onChange(of: store.demoEventsEnabled) { _ in Haptics.tick() }
                } header: {
                    Text("Demo")
                } footer: {
                    Text("Adds a few illustrative events (a late show, an early flight, a big presentation) anchored to today so you can see how the Agenda plans your sleep around them — no calendar access needed.")
                }

                if store.mode == .live {
                    Section("Connections") {
                        connectionRow(
                            title: "Apple Health",
                            systemImage: "heart.fill",
                            tint: .pink,
                            connected: health.authorized,
                            action: { await health.requestAuthorization(); await store.refresh(health: health, calendar: calendar) })
                        connectionRow(
                            title: "Calendar",
                            systemImage: "calendar",
                            tint: Theme.ember,
                            connected: calendar.isAuthorized,
                            action: { await calendar.requestAccess(); await store.refresh(health: health, calendar: calendar) })
                        if SleepClimateService.isSupported {
                            connectionRow(
                                title: "Sleep Climate",
                                systemImage: "thermometer.medium",
                                tint: Theme.cool,
                                connected: store.sleepClimate != nil,
                                action: { await sleepClimate.refresh(store: store) })
                        }
                        if store.healthAuthorized && !store.liveHasData {
                            Label("No sleep data found in Apple Health for the last 60 days.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(Theme.secondaryText)
                        }
                    }

                    Section("Personalization") {
                        TextField("Your name", text: $store.displayName)
                        TextField("Warming method", text: $store.warmingMethod)
                    }
                }
                Section {
                    Label("Sleep Climate uses approximate location to factor overnight heat and humidity into coaching when it is relevant.", systemImage: "cloud.sun.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }

                if WakeAlarmService.isSupported {
                    Section {
                        Toggle("Auto-adjust for early events", isOn: $wakeAlarm.autoAdaptEnabled)
                            .tint(Theme.ember)
                            .onChange(of: wakeAlarm.autoAdaptEnabled) { _ in Haptics.tick() }
                    } header: {
                        Text("Wake Alarm")
                    } footer: {
                        Text("Re-arms nightly and wakes you earlier before early obligations, with a notification explaining why.")
                    }
                }

                Section {
                    HStack {
                        Label("AI categorization", systemImage: "sparkles")
                        Spacer()
                        if store.aiConfigured {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
                        }
                    }
                    SecureField(store.aiConfigured ? "AI access key saved" : "AI access key", text: $apiKeyDraft)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Model", text: $store.llmModel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Base URL", text: $store.llmBaseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if store.aiConfigured {
                        Button("Re-categorize calendar now") {
                            Haptics.light()
                            Task { await store.categorizeCalendar(calendar: calendar) }
                        }
                        Button("Remove AI access", role: .destructive) {
                            Haptics.light()
                            store.setAPIKey(""); apiKeyDraft = ""
                        }
                    }
                    if let err = store.aiError {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                } header: {
                    Text("Agenda intelligence")
                } footer: {
                    Text("Calendar event text is used to sort events into sleep-relevant categories and personalize recommendations.")
                }

                Section {
                    Label("Pod content is illustrative until social sync is connected.",
                          systemImage: "person.3.fill")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }

                Section {
                    LabeledContent("Display name", value: auth.displayName)
                    LabeledContent("Email", value: auth.email)

                    Button("Sign Out", role: .destructive) {
                        Haptics.light()
                        Task {
                            await auth.signOut()
                            dismiss()
                        }
                    }
                    .disabled(auth.isLoading)
                } header: {
                    Text("Account")
                } footer: {
                    Text("Sign in again to continue using Ember.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.light()
                        if !apiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.setAPIKey(apiKeyDraft)
                            apiKeyDraft = ""
                        }
                        store.persistSettings()
                        Task { await store.refresh(health: health, calendar: calendar) }
                        dismiss()
                    }
                }
            }
        }
    }

    private func connectionRow(title: String, systemImage: String, tint: Color,
                               connected: Bool, action: @escaping () async -> Void) -> some View {
        HStack {
            Label(title, systemImage: systemImage).foregroundStyle(tint)
            Spacer()
            if connected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint)
            } else {
                Button("Connect") {
                    Haptics.light()
                    Task { await action() }
                }
                    .buttonStyle(.borderedProminent).tint(tint).controlSize(.small)
            }
        }
    }
}
