import SwiftUI

/// Level completion celebration overlay — matches ParkVision's LevelCompletionView.
///
/// Displays confetti particles, sequentially revealed stars,
/// move count with par comparison, animated score counter,
/// and continuation actions.
/// Timed celebration sequence: background → title → confetti → stars → moves → score → button.
struct LevelCompletionOverlay: View, PlatformAdaptiveSizing {
    let stage: Stage
    let level: Level
    let moveCount: Int
    let parMoves: Int?
    let starDelta: Int
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager

    // MARK: - Animation State

    @State private var showBackground = false
    @State private var showTitle = false
    @State private var revealedStars = 0
    @State private var showMoves = false
    @State private var showScore = false
    @State private var showScoreDelta = false
    @State private var animatedScore: Int = 0
    @State private var showButton = false
    @State private var confettiTrigger = 0

    private var localNumber: Int {
        Stage.localLevelNumber(for: level.number)
    }

    private var stars: Int {
        GameManager.calculateStars(moves: moveCount, optimal: parMoves)
    }

    /// Score gained is the actual delta from the previous best star rating.
    private var scoreGained: Int {
        starDelta * 100
    }

    /// Total score across all levels.
    private var totalScore: Int {
        gameManager.totalStars * 100
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(showBackground ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps */ }

            // Confetti layer
            ConfettiOverlay(trigger: confettiTrigger)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Central celebration card
            VStack(spacing: 24) {
                // "Level Complete!" title
                Text("Level Complete!")
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .scaleEffect(showTitle ? 1.0 : 0.3)
                    .opacity(showTitle ? 1.0 : 0)

                // Stars
                HStack(spacing: starSpacing) {
                    ForEach(0..<3, id: \.self) { index in
                        starView(at: index)
                    }
                }
                .padding(.vertical, 8)

                // Moves summary
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: movesFontSize * 0.8))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("\(moveCount) moves")
                            .font(.system(size: movesFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .opacity(showMoves ? 1 : 0)
                    .scaleEffect(showMoves ? 1 : 0.8)

                    if let par = parMoves, par > 0 {
                        Text("Par: \(par)")
                            .font(.system(size: movesFontSize * 0.85, weight: .medium, design: .rounded))
                            .foregroundStyle(moveCount <= par ? .green : .white.opacity(0.6))
                            .monospacedDigit()
                            .opacity(showMoves ? 1 : 0)
                            .scaleEffect(showMoves ? 1 : 0.8)
                    }
                }

                // Score display
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: totalScoreFontSize * 0.9))
                            .foregroundStyle(.yellow)
                        Text("\(animatedScore)")
                            .contentTransition(.numericText(countsDown: false))
                            .font(.system(size: totalScoreFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .opacity(showScore ? 1 : 0)
                    .scaleEffect(showScore ? 1 : 0.8)

                    // "+N" bonus badge
                    Text(scoreGained >= 0 ? "+\(scoreGained)" : "\(scoreGained)")
                        .font(.system(size: scoreBonusFontSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreGained >= 0 ? .green : .red)
                        .opacity(showScoreDelta ? 1 : 0)
                        .scaleEffect(showScoreDelta ? 1 : 0.3)
                        .offset(y: showScoreDelta ? 0 : 10)
                }

                // Level info
                Text("\(stage.displayName) • Level \(localNumber)")
                    .font(.subheadline)
                    .foregroundStyle(stage.themeColor)
                    .opacity(showMoves ? 1 : 0)

                // Action buttons
                VStack(spacing: 12) {
                    if gameManager.hasNextLevel(after: level.number) {
                        Button {
                            navigateToNextLevel()
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                #if os(visionOS)
                                .background(.ultraThinMaterial, in: Capsule())
                                #else
                                .glassEffect(in: Capsule())
                                #endif
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)
                    }

                    Button {
                        path.removeLast(path.count)
                    } label: {
                        Text("Main Menu")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.8)
                .padding(.top, 8)
            }
            .padding(40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level complete. \(stars) of 3 stars. \(moveCount) moves\(parMoves.map { ", par \($0)" } ?? ""). Score plus \(scoreGained), total \(totalScore).")
        .accessibilityAddTraits(.isModal)
        .task(id: stars) { await runCelebrationSequence() }
    }

    // MARK: - Star View

    @ViewBuilder
    private func starView(at index: Int) -> some View {
        let isRevealed = index < revealedStars
        let isEarned = index < stars

        ZStack {
            Image(systemName: "star")
                .font(.system(size: starSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))

            if isEarned {
                Image(systemName: "star.fill")
                    .font(.system(size: starSize, weight: .bold))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: isRevealed ? 12 : 0)
                    .scaleEffect(isRevealed ? 1.0 : 0.01)
                    .opacity(isRevealed ? 1.0 : 0)
                    .rotationEffect(.degrees(isRevealed ? 0 : -180))
            }
        }
    }

    // MARK: - Celebration Sequence

    @MainActor
    private func runCelebrationSequence() async {
        // Reset
        showBackground = false
        showTitle = false
        revealedStars = 0
        showMoves = false
        showScore = false
        showScoreDelta = false
        showButton = false

        guard stars > 0 else { return }

        // 1. Background fade in
        withAnimation(.easeOut(duration: 0.3)) {
            showBackground = true
        }
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }

        // 2. Title bounce in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showTitle = true
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        // 3. Launch confetti
        confettiTrigger += 1

        // 4. Reveal stars one by one
        for i in 1...stars {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                revealedStars = i
            }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
        }

        // Also reveal empty star slots for unearned stars
        if stars < 3 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                revealedStars = 3
            }
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        // 5. Show move count
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showMoves = true
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        // 6. Show score
        let startScore = totalScore - scoreGained
        animatedScore = startScore

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showScore = true
        }

        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }

        // 7. Show score delta
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            showScoreDelta = true
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        // 8. Animate score counter
        let absGain = abs(scoreGained)
        let delayPerPoint: UInt64 = absGain <= 5 ? 120 : (absGain <= 8 ? 80 : 60)
        let step = scoreGained >= 0 ? 1 : -1
        if scoreGained != 0 {
            // Count in larger steps for big numbers
            let countStep = max(1, absGain / 10)
            for nextScore in stride(from: startScore + step * countStep, through: totalScore, by: step * countStep) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    animatedScore = nextScore
                }
                try? await Task.sleep(for: .milliseconds(delayPerPoint))
                guard !Task.isCancelled else { return }
            }
            // Ensure final value
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                animatedScore = totalScore
            }
        }

        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }

        // 9. Show continue button
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showButton = true
        }
    }

    // MARK: - Navigation

    private var navigator: LevelNavigator {
        LevelNavigator(path: $path, gameManager: gameManager)
    }

    private func navigateToNextLevel() {
        navigator.goToNextLevel(after: level, in: stage)
    }
}
