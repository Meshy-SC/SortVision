import SwiftUI

// MARK: - GameToolbar

/// Bottom toolbar for the game scene — mirrors ParkVision's GameToolbar.
///
/// Provides Previous, Undo, Restart, and Next level buttons
/// in a translucent capsule.
struct GameToolbar: View {

    let canGoToPreviousLevel: Bool
    let canGoToNextLevel: Bool
    let canUndo: Bool

    let onPrevious: () -> Void
    let onRestart: () -> Void
    let onUndo: () -> Void
    let onNext: () -> Void

    /// Trigger counter for button haptic feedback.
    @State private var hapticTrigger = 0

    var body: some View {
        HStack {
            // Previous level
            Button {
                hapticTrigger += 1
                onPrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoToPreviousLevel)
            .accessibilityLabel("Previous level")

            Spacer()

            // Undo
            Button {
                hapticTrigger += 1
                onUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .accessibilityLabel("Undo last move")
            #if os(macOS)
            .keyboardShortcut("z", modifiers: .command)
            #endif

            Spacer()

            // Restart
            Button {
                hapticTrigger += 1
                onRestart()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restart level")
            #if os(macOS)
            .keyboardShortcut("r", modifiers: .command)
            #endif

            Spacer()

            // Next level
            Button {
                hapticTrigger += 1
                onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoToNextLevel)
            .accessibilityLabel("Next level")
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        #if os(iOS)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        #endif
    }
}
