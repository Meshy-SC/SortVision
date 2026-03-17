import SwiftUI

/// Level completion overlay with world-themed styling.
///
/// Displays a celebration card with the world icon, completion message,
/// and navigation buttons. Uses the world's theme color throughout.
struct LevelCompletionOverlay: View {
    let stage: Stage
    let level: Level
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager
    @AccessibilityFocusState private var isOverlayFocused: Bool

    private let toastMessages = [
        "Great!", "Awesome!", "Well Done!", "Amazing!",
        "Perfect!", "Brilliant!", "Fantastic!", "Excellent!",
    ]

    @State private var displayedMessage: String = "Great!"

    private var localNumber: Int {
        Stage.localLevelNumber(for: level.number)
    }

    var body: some View {
        ZStack {
            // Dimmed scrim
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 24) {
                // World icon with theme color
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [stage.themeColor, stage.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, options: .nonRepeating)
                }
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(displayedMessage)
                        .font(.title.bold())
                        .accessibilityFocused($isOverlayFocused)

                    Text("Level \(localNumber) Complete")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("\(stage.displayName) • World \(stage.worldNumber)")
                        .font(.subheadline)
                        .foregroundStyle(stage.themeColor)
                }

                Divider()
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    if gameManager.hasNextLevel(after: level.number) {
                        Button {
                            navigateToNextLevel()
                        } label: {
                            HStack {
                                Text("Next Level")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: 240)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(stage.themeColor)
                        .controlSize(.large)
                        .accessibilityHint("Advances to level \(localNumber + 1)")
                        .keyboardShortcut(.defaultAction)
                    }

                    Button {
                        path.removeLast(path.count)
                    } label: {
                        HStack {
                            Image(systemName: "house")
                            Text("Main Menu")
                        }
                        .frame(maxWidth: 240)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityHint("Returns to the main menu")
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            #if !os(visionOS)
            .glassEffect()
            #endif
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(stage.themeColor.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 24, y: 8)
            .padding(.horizontal, 40)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            displayedMessage = toastMessages.randomElement() ?? "Great!"
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                isOverlayFocused = true
            }
        }
    }

    private func navigateToNextLevel() {
        let nextGlobalNumber = level.number + 1
        guard let nextLevel = gameManager.level(globalNumber: nextGlobalNumber),
              let nextStage = Stage.stage(for: nextGlobalNumber)
        else { return }

        if nextStage == stage {
            // Same world — just swap the gameplay screen
            path.removeLast()
            path.append(AppScreen.gameplay(stage, nextLevel))
        } else {
            // Crossed into a new world — navigate fresh
            path.removeLast(path.count)
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                path.append(AppScreen.levelGrid(nextStage))
                path.append(AppScreen.gameplay(nextStage, nextLevel))
            }
        }
    }
}
