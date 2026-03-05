import SwiftUI

/// Level selection grid. Mirrors Unity's LevelsPanel with LevelTile buttons.
/// Shows level number, lock state (locked/available/completed) per tile.
struct LevelGridView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath
    let gameMode: GameMode

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.13, blue: 0.20),
                    Color(red: 0.16, green: 0.20, blue: 0.30),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("\(gameMode.displayName) Levels")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        let levels = gameManager.levels(for: gameMode)
                        ForEach(levels) { level in
                            LevelTileView(
                                levelNumber: level.no,
                                isLocked: gameManager.isLevelLocked(
                                    mode: gameMode, number: level.no),
                                isCompleted: level.no <= gameManager.completedLevel(for: gameMode)
                            ) {
                                if !gameManager.isLevelLocked(mode: gameMode, number: level.no) {
                                    path.append(AppScreen.gameplay(gameMode, level))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

/// Individual level tile button. Mirrors Unity's LevelTile:
/// - Locked: gray with lock icon
/// - Available: blue, shows level number
/// - Completed: blue with checkmark
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

    private var tileColor: Color {
        if isLocked {
            return Color.gray.opacity(0.25)
        } else if isCompleted {
            return Color(red: 0.16, green: 0.50, blue: 0.73).opacity(0.7)
        } else {
            return Color(red: 0.16, green: 0.50, blue: 0.73).opacity(0.45)
        }
    }
}
