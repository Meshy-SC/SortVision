import SwiftUI

/// Individual level tile button for the level selection grid.
///
/// Displays one of three visual states:
/// - **Locked**: Gray background with lock icon (non-interactive)
/// - **Available**: Blue background showing the level number
/// - **Completed**: Blue background with level number and green checkmark
///
/// Mirrors Unity's `LevelTile` prefab behavior.
struct LevelTileView: View {
    let levelNumber: Int
    let isLocked: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tileColor)
                    .frame(height: 60)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    VStack(spacing: 2) {
                        Text("\(levelNumber)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .disabled(isLocked)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(isLocked ? "Level is locked" : "Double tap to play level \(levelNumber)")
        .accessibilityAddTraits(isLocked ? .isButton : [.isButton])
        .accessibilityRemoveTraits(isLocked ? .isButton : [])
    }

    /// Determines tile background color based on its current state.
    private var tileColor: Color {
        switch (isLocked, isCompleted) {
        case (true, _):  Color.gray.opacity(0.25)
        case (_, true):  Color(red: 0.16, green: 0.50, blue: 0.73).opacity(0.7)
        case (_, false): Color(red: 0.16, green: 0.50, blue: 0.73).opacity(0.45)
        }
    }

    /// Descriptive accessibility label for VoiceOver.
    private var accessibilityLabelText: String {
        if isLocked {
            return "Level \(levelNumber), locked"
        } else if isCompleted {
            return "Level \(levelNumber), completed"
        } else {
            return "Level \(levelNumber)"
        }
    }
}
