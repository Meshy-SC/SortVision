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
            Color.clear
                .gameBackground()

            VStack(spacing: 24) {
                Text("Select Difficulty")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 40)

                Spacer()

                // Difficulty buttons — uses built-in borderedProminent style
                // Automatic Liquid Glass on iOS 26+; platform-adaptive sizing
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
                        }
                        .frame(maxWidth: 320)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(item.color)
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                }

                Spacer()
            }
        }
    }
}
