import SwiftUI

/// Level completion celebration overlay — matches Pushbox's LevelCompletionView.
///
/// Displays confetti particles, sequentially revealed stars,
/// move count with par comparison, and an animated score counter.
/// Timed celebration sequence: background → title → confetti → stars → moves → button.
struct LevelCompletionOverlay: View {
    let stage: Stage
    let level: Level
    let moveCount: Int
    let parMoves: Int?
    @Binding var path: NavigationPath
    @Environment(GameManager.self) private var gameManager

    // MARK: - Animation State

    @State private var showBackground = false
    @State private var showTitle = false
    @State private var revealedStars = 0
    @State private var showMoves = false
    @State private var showButton = false
    @State private var confettiTrigger = 0

    private var localNumber: Int {
        Stage.localLevelNumber(for: level.number)
    }

    private var stars: Int {
        GameManager.calculateStars(moves: moveCount, optimal: parMoves)
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
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .scaleEffect(showTitle ? 1.0 : 0.3)
                    .opacity(showTitle ? 1.0 : 0)

                // Stars
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { index in
                        starView(at: index)
                    }
                }
                .padding(.vertical, 8)

                // Move count and par
                VStack(spacing: 4) {
                    Text("\(moveCount) Moves")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    if let par = parMoves {
                        Text("Par: \(par)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(moveCount <= par ? .green : .white.opacity(0.6))
                    }
                }
                .opacity(showMoves ? 1 : 0)
                .scaleEffect(showMoves ? 1 : 0.8)

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
                                .background(.ultraThinMaterial, in: Capsule())
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
        .accessibilityLabel("Level complete. \(moveCount) moves\(parMoves.map { ", par \($0)" } ?? ""). \(stars) of 3 stars.")
        .accessibilityAddTraits(.isModal)
        .task(id: stars) { await runCelebrationSequence() }
    }

    // MARK: - Star View

    @ViewBuilder
    private func starView(at index: Int) -> some View {
        let isRevealed = index < revealedStars
        let isEarned = index < stars

        ZStack {
            // Empty star (always visible once revealed)
            Image(systemName: "star")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))

            // Filled star (only if earned)
            if isEarned {
                Image(systemName: "star.fill")
                    .font(.system(size: 48, weight: .bold))
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
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }

        // 6. Show continue button
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showButton = true
        }
    }

    // MARK: - Navigation

    private func navigateToNextLevel() {
        let nextGlobalNumber = level.number + 1
        guard let nextLevel = gameManager.level(globalNumber: nextGlobalNumber),
              let nextStage = Stage.stage(for: nextGlobalNumber)
        else { return }

        if nextStage == stage {
            path.removeLast()
            path.append(AppScreen.gameplay(stage, nextLevel))
        } else {
            path.removeLast(path.count)
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                path.append(AppScreen.levelGrid(nextStage))
                path.append(AppScreen.gameplay(nextStage, nextLevel))
            }
        }
    }
}

// MARK: - ConfettiOverlay

/// Pure-SwiftUI confetti particle system using Canvas + TimelineView.
/// Generates bursts of colorful shapes that fall with physics-inspired motion.
private struct ConfettiOverlay: View {
    let trigger: Int

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: particles.isEmpty)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let age = now - particle.birthTime
                    guard age < particle.lifetime else { continue }

                    let gravity: Double = 350
                    let x = particle.startX * size.width + particle.velocityX * age + particle.wobbleAmplitude * sin(particle.wobbleFrequency * age)
                    let y = particle.startY * size.height + particle.velocityY * age + 0.5 * gravity * age * age
                    let rotation = Angle.degrees(particle.rotationSpeed * age)
                    let fadeProgress = age / particle.lifetime
                    let opacity = fadeProgress < 0.7 ? 1.0 : max(0, 1.0 - (fadeProgress - 0.7) / 0.3)
                    let scale = 1.0 - fadeProgress * 0.3

                    guard y < size.height + 50 else { continue }

                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rotation)
                    ctx.scaleBy(x: scale, y: scale)
                    ctx.opacity = opacity

                    let rect = CGRect(x: -particle.width / 2, y: -particle.height / 2, width: particle.width, height: particle.height)

                    switch particle.shape {
                    case .rectangle:
                        ctx.fill(Path(rect), with: .color(particle.color))
                    case .circle:
                        ctx.fill(Path(ellipseIn: rect), with: .color(particle.color))
                    case .triangle:
                        var triPath = Path()
                        triPath.move(to: CGPoint(x: 0, y: -particle.height / 2))
                        triPath.addLine(to: CGPoint(x: particle.width / 2, y: particle.height / 2))
                        triPath.addLine(to: CGPoint(x: -particle.width / 2, y: particle.height / 2))
                        triPath.closeSubpath()
                        ctx.fill(triPath, with: .color(particle.color))
                    }
                }
            }
        }
        .onChange(of: trigger) {
            spawnBurst()
        }
    }

    private func spawnBurst() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .cyan, .mint]
        let now = Date.timeIntervalSinceReferenceDate
        var newParticles: [ConfettiParticle] = []

        for _ in 0..<80 {
            let shape = ConfettiShape.allCases.randomElement() ?? .rectangle
            let color = colors.randomElement() ?? .yellow
            newParticles.append(ConfettiParticle(
                birthTime: now + Double.random(in: 0...0.3),
                lifetime: Double.random(in: 2.5...4.0),
                startX: Double.random(in: 0.2...0.8),
                startY: Double.random(in: -0.15...(-0.05)),
                velocityX: Double.random(in: -120...120),
                velocityY: Double.random(in: -80...60),
                rotationSpeed: Double.random(in: -720...720),
                wobbleAmplitude: Double.random(in: 10...40),
                wobbleFrequency: Double.random(in: 3...8),
                width: Double.random(in: 6...12),
                height: Double.random(in: 4...10),
                color: color,
                shape: shape
            ))
        }

        particles.append(contentsOf: newParticles)

        Task {
            try? await Task.sleep(for: .seconds(5))
            particles.removeAll { particle in
                Date.timeIntervalSinceReferenceDate - particle.birthTime > particle.lifetime
            }
        }
    }
}

// MARK: - Confetti Models

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let birthTime: Double
    let lifetime: Double
    let startX: Double
    let startY: Double
    let velocityX: Double
    let velocityY: Double
    let rotationSpeed: Double
    let wobbleAmplitude: Double
    let wobbleFrequency: Double
    let width: Double
    let height: Double
    let color: Color
    let shape: ConfettiShape
}

private enum ConfettiShape: CaseIterable {
    case rectangle, circle, triangle
}
