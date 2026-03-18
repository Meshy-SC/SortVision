// ControlPanelWindowView.swift
#if os(visionOS)
// Standalone 2D window hosting the control panel for level/world selection.

import SwiftUI

/// visionOS window that hosts the control panel for world and level selection.
///
/// Manages the lifecycle of the immersive game space:
/// - Opens `GameSpace` when the game phase transitions to `.placing` or `.playing`
/// - Dismisses itself after the immersive space opens successfully
/// - Tracks window visibility via `appModel.isControlPanelOpen`
struct ControlPanelWindowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        ControlPanelView()
            .environment(appModel)
            .frame(minWidth: 700, idealWidth: 850, minHeight: 450, idealHeight: 575)
            .glassBackgroundEffect()
            .onChange(of: appModel.gamePhase) { _, phase in
                switch phase {
                case .placing, .playing:
                    Task {
                        let result = await openImmersiveSpace(id: "GameSpace")
                        if case .error = result {
                            AppLogger.ui.error("Failed to open immersive space")
                            appModel.gamePhase = .controlPanel
                            return
                        }
                        // Dismiss control panel after immersive space opens
                        dismissWindow(id: "ControlPanel")
                    }
                case .controlPanel:
                    break
                }
            }
            .onAppear {
                appModel.isControlPanelOpen = true
            }
            .onDisappear {
                appModel.isControlPanelOpen = false
            }
    }
}
#endif
