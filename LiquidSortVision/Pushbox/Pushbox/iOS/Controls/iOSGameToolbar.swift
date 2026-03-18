// iOSGameToolbar.swift
// Bottom toolbar for the iOS game scene — replaces visionOS ornaments.

#if os(iOS) || os(macOS) || os(tvOS)
import SwiftUI

/// A translucent bottom toolbar for the iOS game scene with
/// undo, navigation, solution, and settings buttons.
struct iOSGameToolbar: View {
    
    @Environment(AppModel.self) private var appModel
    
    let undoAction: () -> Void
    let previousLevelAction: () -> Void
    let nextLevelAction: () -> Void
    let solutionAction: () -> Void
    let isLevelReady: Bool
    let isUndoDisabled: Bool
    
    /// Trigger counter for button haptic feedback via `.sensoryFeedback()`.
    @State private var hapticTrigger = 0

    /// Whether the locked-level alert is presented for the next level.
    @State private var showLockedAlert = false
    
    var body: some View {
        GlassEffectContainer {
            HStack {
                // Previous level
                Button(action: {
                    hapticTrigger += 1
                    previousLevelAction()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(appModel.selectedLevelIndex == nil || appModel.selectedLevelIndex == 0)
                .accessibilityLabel("Previous level")

                Spacer()

                // Solution bulb — shared component
                SolutionButton(action: {
                    hapticTrigger += 1
                    solutionAction()
                }, isLevelReady: isLevelReady)
                .environment(appModel)

                Spacer()

                // Solution credits purchase
                Button(action: {
                    hapticTrigger += 1
                    appModel.inAppPurchaseService.isStoreSheetPresented = true
                }) {
                    Image(systemName: "cart.fill")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buy solution credits")

                Spacer()

                // Undo
                Button(action: {
                    hapticTrigger += 1
                    undoAction()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isUndoDisabled)
                .accessibilityLabel("Undo last move")

                Spacer()

                // Next level
                Button(action: {
                    hapticTrigger += 1
                    if appModel.isNextLevelLocked {
                        showLockedAlert = true
                    } else {
                        nextLevelAction()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!appModel.hasNextLevel)
                .opacity(appModel.isNextLevelLocked ? 0.4 : 1)
                .accessibilityLabel("Next level")
                .accessibilityHint(appModel.isNextLevelLocked ? "Level is locked" : "")
                .alert("Level Locked", isPresented: $showLockedAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(appModel.nextLevelLockMessage ?? "Complete more levels to unlock the next level.")
                }
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .glassEffect(in: .capsule)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        #if !os(tvOS)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        #endif
    }
    
}
#endif
