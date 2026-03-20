import SwiftUI

// MARK: - SettingsView

/// Settings view mirroring ParkVision's SettingsView pattern.
///
/// Section ordering follows Apple HIG:
/// Audio → Feedback → Support & Data → About
struct SettingsView: View {

    // MARK: Environment

    @Environment(GameManager.self) private var gameManager
    @Environment(\.openURL) private var openURL

    // MARK: State

    @State private var showingCopiedAlert = false
    @State private var isResetConfirmationPresented = false

    // MARK: Body

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

    private var audioSection: some View {
        Section {
            NavigationLink {
                AudioSettingsView()
            } label: {
                Label("Audio", systemImage: "speaker.wave.2.fill")
            }
        } header: {
            Text("Audio")
        } footer: {
            Text("Customize sound effects.")
        }
    }

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
                Button("OK", role: .cancel) {}
            } message: {
                Text("Our email address has been copied to your clipboard. Paste it into your preferred email app to send us feedback.")
            }
        } header: {
            Text("Feedback")
        } footer: {
            Text("We'd love to hear from you! Share suggestions, bug reports, or ideas.")
        }
    }

    private static let supportURL = URL(string: "https://github.com/Meshy-SC/SortVision/blob/main/SUPPORT.md")
    private static let privacyURL = URL(string: "https://github.com/Meshy-SC/SortVision/blob/main/PRIVACY_POLICY.md")

    private var supportSection: some View {
        Section {
            if let url = Self.supportURL {
                Link(destination: url) {
                    Label {
                        HStack {
                            Text("Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "questionmark.circle.fill")
                    }
                }
                .accessibilityHint("Opens support page in your browser")
            }

            if let url = Self.privacyURL {
                Link(destination: url) {
                    Label {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                    }
                }
                .accessibilityHint("Opens privacy policy in your browser")
            }

            Button(role: .destructive) {
                isResetConfirmationPresented = true
            } label: {
                Label("Reset All Progress", systemImage: "arrow.counterclockwise")
            }
            .accessibilityHint("Double-tap to reset all level completions and star ratings. This cannot be undone.")
            .alert("Reset All Progress?", isPresented: $isResetConfirmationPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    gameManager.resetAllProgress()
                }
            } message: {
                Text("This will permanently delete all level completions, star ratings, and scores. This cannot be undone.")
            }
        } header: {
            Text("Support & Data")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle.fill")
                Spacer()
                Text(PlatformInfo.versionDisplay)
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

    private func sendFeedback() {
        let email = "davinci.dalhi@gmail.com"
        let subject = "SortVision Feedback | \(PlatformInfo.platformName) | v\(PlatformInfo.appVersion) | \(PlatformInfo.systemName) \(PlatformInfo.systemVersion) \(PlatformInfo.deviceModel)"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject)
        ]
        guard let mailURL = components.url else { return }
        openURL(mailURL) { accepted in
            if !accepted {
                #if os(iOS) || os(visionOS)
                UIPasteboard.general.string = email
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(email, forType: .string)
                #endif
                showingCopiedAlert = true
            }
        }
    }

}

// AudioSettingsView and CreditsView are in Views/Settings/
