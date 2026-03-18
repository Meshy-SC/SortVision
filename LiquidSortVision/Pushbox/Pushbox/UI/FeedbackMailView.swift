// FeedbackMailView.swift
// Wraps MFMailComposeViewController for in-app feedback on iOS.
// Falls back to a mailto: URL on macOS and visionOS.

import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

// MARK: - Feedback Constants

@MainActor
enum FeedbackConfig {
    static let recipientEmail = "davinci.dalhi@gmail.com"

    // MARK: - Platform & Device Helpers

    private static var platform: String {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "iPad"
        }
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #elseif os(tvOS)
        return "tvOS"
        #else
        return "Unknown"
        #endif
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private static var systemName: String {
        #if os(iOS)
        return UIDevice.current.systemName
        #elseif os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #elseif os(tvOS)
        return "tvOS"
        #else
        return "Unknown"
        #endif
    }

    private static var systemVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #endif
    }

    private static var deviceModel: String {
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

    // MARK: - Subject & Body

    /// All diagnostic info packed into the subject line.
    /// Example: "Push Box Feedback | iOS | v26.0.9 | iOS 26.3.1 iPhone"
    static var subject: String {
        "Push Box Feedback | \(platform) | v\(appVersion) | \(systemName) \(systemVersion) \(deviceModel)"
    }

    /// Empty body so the user can type their message directly.
    static var body: String { "" }
}

// MARK: - iOS Mail Compose

#if canImport(MessageUI)
/// UIKit wrapper for `MFMailComposeViewController` on iOS.
struct FeedbackMailView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([FeedbackConfig.recipientEmail])
        composer.setSubject(FeedbackConfig.subject)
        composer.setMessageBody(FeedbackConfig.body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            MainActor.assumeIsolated {
                controller.dismiss(animated: true)
            }
        }
    }
}
#endif

// MARK: - Send Feedback Button

/// A reusable "Send Feedback" button that presents the mail composer on iOS
/// or opens a `mailto:` URL on macOS / visionOS.
struct SendFeedbackButton: View {
    #if canImport(MessageUI)
    @State private var isMailPresented = false
    @State private var showMailUnavailableAlert = false
    #endif

    var body: some View {
        Button {
            sendFeedback()
        } label: {
            Label("Send Feedback", systemImage: "envelope")
        }
        #if canImport(MessageUI)
        .sheet(isPresented: $isMailPresented) {
            FeedbackMailView()
        }
        .alert("Mail Not Available", isPresented: $showMailUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please configure a Mail account in Settings, or send feedback to \(FeedbackConfig.recipientEmail).")
        }
        #endif
    }

    private func sendFeedback() {
        #if canImport(MessageUI)
        if MFMailComposeViewController.canSendMail() {
            isMailPresented = true
        } else {
            // Try mailto: as fallback, otherwise show alert
            if let url = mailtoURL, UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                showMailUnavailableAlert = true
            }
        }
        #else
        // macOS / visionOS — open mailto: URL via the default mail client
        if let url = mailtoURL {
            openMailtoURL(url)
        }
        #endif
    }

    private var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = FeedbackConfig.recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: FeedbackConfig.subject),
            URLQueryItem(name: "body", value: FeedbackConfig.body)
        ]
        return components.url
    }

    #if os(macOS)
    private func openMailtoURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    #elseif os(visionOS) || os(tvOS)
    @Environment(\.openURL) private var openURL
    private func openMailtoURL(_ url: URL) {
        openURL(url)
    }
    #endif
}
