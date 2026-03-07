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
                            .font(.system(size: 18, weight: .bold, design: .rounded))
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
    }

    /// Determines tile background color based on its current state.
    private var tileColor: Color {
        if isLocked {
            Color.gray.opacity(0.25)
        } else if isCompleted {
            Color(red: 0.16, green: 0.50, blue: 0.73).opacity(0.7)
        } else {
            Color(red: 0.16, green: 0.50, blue: 0.73).opacity(0.45)
        }
    }
}
