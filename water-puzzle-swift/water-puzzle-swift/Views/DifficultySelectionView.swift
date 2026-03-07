import SwiftUI

/// Difficulty selection screen. Mirrors Unity's GameModePanel with Easy/Normal/Hard buttons.
/// Adds Expert for the fourth level file.
struct DifficultySelectionView: View {
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
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 40)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                // Difficulty buttons — uses built-in borderedProminent style
                // Automatic Liquid Glass on iOS 26+; platform-adaptive sizing
                ForEach(modes, id: \.mode) { item in
                    let completed = gameManager.completedLevel(for: item.mode)
                    let total = gameManager.levels(for: item.mode).count

                    Button {
                        path.append(AppScreen.levelGrid(item.mode))
                    } label: {
                        HStack {
                            Text(item.mode.displayName)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Spacer()
                            Text("\(completed)/\(total)")
                                .font(.callout)
                        }
                        .frame(maxWidth: 320)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(item.color)
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .accessibilityLabel("\(item.mode.displayName), \(completed) of \(total) completed")
                    .accessibilityHint("Double tap to view \(item.mode.displayName) levels")
                }

                Spacer()
            }
        }
        .navigationTitle("Difficulty")
        #if os(iOS)
        .toolbarVisibility(.hidden, for: .navigationBar)
        #endif
    }
}
