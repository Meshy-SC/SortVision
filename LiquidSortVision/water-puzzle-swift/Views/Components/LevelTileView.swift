import SwiftUI

/// Individual level tile with world-themed styling.
///
/// Displays a circular tile with the level number, a checkmark
/// for completed levels, or a lock icon for locked levels.
/// Uses the world's theme color for visual consistency.
struct LevelTileView: View {
    let levelNumber: Int
    let isLocked: Bool
    let isCompleted: Bool
    let themeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                if isCompleted {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeColor, themeColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(themeColor.opacity(0.3), lineWidth: 1.5)
                        }
                } else {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isLocked
                                        ? Color.secondary.opacity(0.15)
                                        : themeColor.opacity(0.3),
                                    lineWidth: 1.5
                                )
                        }
                }

                // Content
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 2) {
                        Text("\(levelNumber)")
                            .font(.system(.callout, design: .rounded, weight: .bold))
                            .foregroundStyle(isCompleted ? .white : .primary)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .contextMenu {
            if !isLocked {
                Button {
                    action()
                } label: {
                    Label(
                        isCompleted
                            ? "Replay Level \(levelNumber)"
                            : "Play Level \(levelNumber)",
                        systemImage: isCompleted ? "arrow.counterclockwise" : "play.fill"
                    )
                }
            }
        }
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(
            isLocked ? "Level is locked" : "Double tap to play level \(levelNumber)"
        )
    }

    // MARK: - Styling

    private var accessibilityLabelText: String {
        if isLocked { return "Level \(levelNumber), locked" }
        if isCompleted { return "Level \(levelNumber), completed" }
        return "Level \(levelNumber)"
    }
}
