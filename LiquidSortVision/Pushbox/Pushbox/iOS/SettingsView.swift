// SettingsView.swift
// Settings view shared across all platforms.
// Follows Apple HIG section ordering with platform-specific layouts.
//
// Platform placement:
// - macOS: Presented via Settings scene (⌘,)
// - iOS: Pushed from main view via gear toolbar button
// - visionOS: Presented as sheet from control panel

import SwiftUI

// MARK: - Settings Root

/// The app's settings view, following Apple HIG recommended section ordering.
/// Sections: Appearance → Audio → Feedback → Support & Data → About.
struct SettingsView: View {
    
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    
    /// Whether the "Email Copied" alert is shown (feedback fallback).
    @State private var showingCopiedAlert = false
    
    /// Whether the reset progress confirmation alert is presented.
    @State private var isResetConfirmationPresented = false
    
    var body: some View {
        #if os(macOS)
        macOSSettings
        #else
        mobileSettings
        #endif
    }
    
    // MARK: - iOS / visionOS
    
    #if !os(macOS)
    private var mobileSettings: some View {
        Form {
            #if os(iOS)
            appearanceSection
            #endif
            audioSection
            feedbackSection
            supportSection
            aboutSection
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
    #endif
    
    // MARK: - macOS
    
    #if os(macOS)
    private var macOSSettings: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                NavigationStack {
                    Form {
                        appearanceSection
                        audioSection
                    }
                    .formStyle(.grouped)
                }
                .frame(minWidth: 450, minHeight: 280)
            }
            
            Tab("About", systemImage: "info.circle") {
                NavigationStack {
                    Form {
                        feedbackSection
                        supportSection
                        aboutSection
                    }
                    .formStyle(.grouped)
                }
                .frame(minWidth: 450, minHeight: 280)
            }
        }
        .frame(width: 500)
    }
    #endif
    
    // MARK: - Sections
    
    // 1. Appearance (most user-facing preference)
    #if os(iOS) || os(macOS)
    private var appearanceSection: some View {
        Section {
            Picker(selection: Binding(
                get: { appModel.appearanceMode },
                set: { appModel.appearanceMode = $0 }
            )) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon)
                        .tag(mode)
                }
            } label: {
                Label("Appearance", systemImage: "paintbrush.fill")
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif
        } header: {
            Text("Appearance")
        } footer: {
            Text("Choose how Push Box looks. System follows your device setting.")
        }
    }
    #endif
    
    // 2. Audio
    private var audioSection: some View {
        Section {
            NavigationLink {
                AudioSettingsView()
                    .environment(appModel)
            } label: {
                Label("Audio", systemImage: "speaker.wave.2.fill")
            }
        } header: {
            Text("Audio")
        } footer: {
            Text("Customize background music and sound effects.")
        }
    }
    
    // 3. Feedback
    private var feedbackSection: some View {
        Section {
            Button {
                sendFeedback()
            } label: {
                Label {
                    HStack {
                        Text("Send Feedback")
                        Spacer()
                        Image(systemName: "envelope.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bubble.left.fill")
                }
            }
            .alert("Email Copied", isPresented: $showingCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Our email address has been copied to your clipboard. Paste it into your preferred email app to send us feedback.")
            }
        } header: {
            Text("Feedback")
        } footer: {
            Text("We'd love to hear from you! Share suggestions, bug reports, or ideas.")
        }
    }
    
    // 4. Support & Data
    private var supportSection: some View {
        Section {
            Button(role: .destructive) {
                isResetConfirmationPresented = true
            } label: {
                Label("Reset All Progress", systemImage: "arrow.counterclockwise")
            }
            .accessibilityHint("Double-tap to reset all level completions and star ratings. This cannot be undone.")
            .alert("Reset All Progress?", isPresented: $isResetConfirmationPresented) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    appModel.progressService.resetAllProgress()
                }
            } message: {
                Text("This will permanently delete all level completions, star ratings, and scores. Your purchased solution credits will not be affected.")
            }
        } header: {
            Text("Support & Data")
        }
    }
    
    // 5. About (always last)
    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle.fill")
                Spacer()
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundStyle(.secondary)
            }
            
            NavigationLink {
                CreditsView()
            } label: {
                Label("Credits", systemImage: "person.2.fill")
            }
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Feedback Helper
    
    /// Attempts to open the mailto link; falls back to copying the email on platforms
    /// without a mail client (e.g. visionOS).
    private func sendFeedback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = FeedbackConfig.recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: FeedbackConfig.subject),
            URLQueryItem(name: "body", value: FeedbackConfig.body)
        ]
        guard let mailURL = components.url else { return }
        openURL(mailURL) { accepted in
            if !accepted {
                // No mail client available (common on visionOS) — copy email to clipboard
                #if os(iOS) || os(visionOS)
                UIPasteboard.general.string = FeedbackConfig.recipientEmail
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(FeedbackConfig.recipientEmail, forType: .string)
                #endif
                showingCopiedAlert = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Audio Settings Sub-Page

/// Audio settings detail view with grouped toggles for background audio and sound effects.
private struct AudioSettingsView: View {
    
    @Environment(AppModel.self) private var appModel

    private var backgroundToggles: [AudioToggleItem] {
        AudioToggleItem.allToggles.filter { $0.id == "puzzle" }
    }
    private var soundEffectToggles: [AudioToggleItem] {
        AudioToggleItem.allToggles.filter { $0.id != "puzzle" }
    }

    var body: some View {
        List {
            Section("Background Audio") {
                ForEach(backgroundToggles) { toggle in
                    toggle.makeToggle(for: appModel)
                }
            }

            Section("Sound Effects") {
                ForEach(soundEffectToggles) { toggle in
                    toggle.makeToggle(for: appModel)
                }
            }
        }
        .navigationTitle("Audio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Credits Sub-Page

/// Displays authorship and level-design acknowledgements.
private struct CreditsView: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Push Box Sokoban Puzzle")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            Section("Designed & Developed By") {
                Text("Ahmed DALHI")
            }

            Section("Level Design") {
                Text("David W. Skinner")
            }
        }
        .navigationTitle("Credits")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        .formStyle(.grouped)
        #endif
    }
}
