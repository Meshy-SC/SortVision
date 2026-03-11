import SwiftUI

/// Level completion — native Apple modal-style overlay.
///
/// Uses system materials, standard button styles, and
/// primary/secondary label colours. No custom forced colours.
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

            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, options: .nonRepeating)
                    .accessibilityHidden(true)

                Text(displayedMessage)
                    .font(.title.bold())
                    .accessibilityFocused($isOverlayFocused)

                Text("Level \(localNumber) Complete")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    if gameManager.hasNextLevel(after: level.number) {
                        Button {
                            navigateToNextLevel()
                        } label: {
                            Text("Next Level")
                                .frame(maxWidth: 240)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityHint("Advances to level \(localNumber + 1)")
                        .keyboardShortcut(.defaultAction)
                    }

                    Button {
                        path.removeLast(path.count)
                    } label: {
                        Text("Main Menu")
                            .frame(maxWidth: 240)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityHint("Returns to the main menu")
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            #if !os(visionOS)
            .glassEffect()
            #endif
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
            // Same stage — just swap the gameplay screen
            path.removeLast()
            path.append(AppScreen.gameplay(stage, nextLevel))
        } else {
            // Crossed into a new stage — navigate fresh
            path.removeLast(path.count)
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                path.append(AppScreen.levelGrid(nextStage))
                path.append(AppScreen.gameplay(nextStage, nextLevel))
            }
        }
    }
}
