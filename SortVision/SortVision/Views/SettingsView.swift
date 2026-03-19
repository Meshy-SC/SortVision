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

    private static let supportURL = URL(string: "https://github.com/Meshy-SC/SortVision/blob/main/SUPPORT")
    private static let privacyURL = URL(string: "https://github.com/Meshy-SC/SortVision/blob/main/PRIVACY_POLICY")

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

    private func sendFeedback() {
        let email = "davinci.dalhi@gmail.com"
        let subject = "SortVision Feedback | \(platformName) | v\(appVersion) | \(systemName) \(systemVersion) \(deviceModel)"
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

    // MARK: - Platform Helpers

    private var platformName: String {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "iPad"
        }
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Unknown"
        #endif
    }

    private var systemName: String {
        #if os(iOS)
        return UIDevice.current.systemName
        #elseif os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Unknown"
        #endif
    }

    private var systemVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #endif
    }

    private var deviceModel: String {
        #if os(iOS)
        return UIDevice.current.model
        #else
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix(while: { $0 != 0 }), as: UTF8.self)
        #endif
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

private struct AudioSettingsView: View {

    @Environment(GameManager.self) private var gameManager

    @State private var isSoundOn: Bool = true
    @State private var hasCompletedInitialSync = false

    var body: some View {
        List {
            Section("Sound Effects") {
                Toggle(isOn: $isSoundOn) {
                    Label("All Sound Effects", systemImage: isSoundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .onChange(of: isSoundOn) {
                    guard hasCompletedInitialSync else { return }
                    gameManager.soundEnabled = isSoundOn
                }
            }
        }
        .navigationTitle("Audio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            isSoundOn = gameManager.soundEnabled
            hasCompletedInitialSync = true
        }
    }
}

// MARK: - Credits Sub-Page

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
                        Text("SortVision!")
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
        }
        .navigationTitle("Credits")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        .formStyle(.grouped)
        #endif
    }
}
