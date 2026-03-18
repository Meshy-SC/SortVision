// CloudKitLifecycleModifier.swift
// App-level modifier that ensures CloudKit sync works reliably across all platforms.
// Handles remote notification registration, save-on-background, and refresh-on-foreground.

import SwiftUI

// MARK: - CloudKit Lifecycle Modifier

/// A view modifier applied at the app level to centralize CloudKit sync lifecycle handling.
///
/// This ensures that regardless of platform or which view is active:
/// - The app registers for remote notifications on launch
/// - Pending changes are flushed when going to background
/// - Fresh data is loaded when returning to foreground
/// - A delayed refresh catches the race condition where `ProgressService.init()` runs
///   before CloudKit has finished importing remote records
private struct CloudKitLifecycleModifier: ViewModifier {

    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                registerForRemoteNotifications()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handlePhaseTransition(from: oldPhase, to: newPhase)
            }
            .task {
                // Delayed refresh to handle the cold-launch race condition:
                // ProgressService.init() calls loadProgress() before CloudKit import completes.
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                appModel.progressService.loadProgress()
                appModel.inAppPurchaseService.refreshFromRemoteChanges()
                AppLogger.cloudKit.debug("Completed delayed post-launch CloudKit refresh")
            }
    }

    private func registerForRemoteNotifications() {
        #if os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
        AppLogger.cloudKit.info("Registered for remote notifications")
    }

    private func handlePhaseTransition(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            appModel.progressService.saveProgress()
            AppLogger.cloudKit.debug("Saved progress on scene phase: \(String(describing: newPhase))")
        case .active:
            if oldPhase == .background || oldPhase == .inactive {
                appModel.progressService.loadProgress()
                appModel.inAppPurchaseService.refreshFromRemoteChanges()
                AppLogger.cloudKit.debug("Refreshed data on return to foreground")
            }
        @unknown default:
            break
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies CloudKit lifecycle handling at the app level.
    func cloudKitLifecycle() -> some View {
        modifier(CloudKitLifecycleModifier())
    }
}
