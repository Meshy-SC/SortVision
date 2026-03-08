import SwiftUI

/// Individual level tile — native Apple button.
///
/// Uses the system `borderedProminent` or `bordered` style
/// depending on state, with standard tint colors and SF Symbols.
struct LevelTileView: View {
    let levelNumber: Int
    let isLocked: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(levelNumber)")
                        .font(.body.weight(.semibold).monospacedDigit())

                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .buttonStyle(.bordered)
        .tint(tileColor)
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

    private var tileColor: Color {
        if isLocked { return .gray }
        if isCompleted { return .blue }
        return .blue
    }

    private var accessibilityLabelText: String {
        if isLocked { return "Level \(levelNumber), locked" }
        if isCompleted { return "Level \(levelNumber), completed" }
        return "Level \(levelNumber)"
    }
}
