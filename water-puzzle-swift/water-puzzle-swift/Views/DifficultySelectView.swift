import SwiftUI

/// Difficulty selection screen. Mirrors Unity's GameModePanel with Easy/Normal/Hard buttons.
/// Adds Expert for the fourth level file.
struct DifficultySelectView: View {
    @Environment(GameManager.self) private var gameManager
    @Binding var path: NavigationPath

    private let modes: [(mode: GameMode, color: Color)] = [
        (.easy, .green),
        (.normal, .blue),
        (.hard, .orange),
        (.expert, .red),
    ]

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

            VStack(spacing: 24) {
                Text("Select Difficulty")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 40)

                Spacer()

                // Difficulty buttons — mirrors Unity difficulty_ui_beginner/advanced/expert sprites
                ForEach(modes, id: \.mode) { item in
                    Button {
                        path.append(AppScreen.levelGrid(item.mode))
                    } label: {
                        HStack {
                            Text(item.mode.displayName)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Spacer()
                            let completed = gameManager.completedLevel(for: item.mode)
                            let total = gameManager.levels(for: item.mode).count
                            Text("\(completed)/\(total)")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30)
                        .frame(height: 65)
                        .frame(maxWidth: 320)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(item.color.opacity(0.75))
                        )
                        .shadow(color: item.color.opacity(0.3), radius: 6, y: 3)
                    }
                }

                Spacer()
            }
        }
    }
}
