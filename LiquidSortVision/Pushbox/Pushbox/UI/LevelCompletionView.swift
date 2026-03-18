// LevelCompletionView.swift
// Animated celebration overlay shown when a level is completed.
// Displays confetti, animated star reveal, and an incrementing score counter.

import SwiftUI

// MARK: - LevelCompletionView

/// A full-screen overlay that celebrates level completion with confetti,
/// sequentially revealed stars, and an animated score counter.
///
/// Usage:
/// ```swift
/// .overlay {
///     if showCompletion {
///         LevelCompletionView(stars: 3, scoreGained: 10, totalScore: 150, pushCount: 8, parPushes: 8, onDismiss: { … })
///     }
/// }
/// ```
struct LevelCompletionView: View {

    // MARK: - Properties

    /// Number of stars earned (1–3).
    let stars: Int

    /// Points scored for this level (5, 7, or 10).
    let scoreGained: Int

    /// Total global score after this level's points were added.
    let totalScore: Int

    /// Number of pushes the player used to complete the level.
    let pushCount: Int

    /// Optimal (par) number of pushes for this level, if known.
    let parPushes: Int?

    /// Called when the user taps "Continue" or the overlay auto-dismisses.
    let onDismiss: () -> Void

    // MARK: - Animation State

    @State private var showBackground = false
    @State private var showTitle = false
    @State private var revealedStars = 0
    @State private var showScore = false
    @State private var showBonus = false
    @State private var animatedScore: Int = 0
    @State private var showButton = false
    @State private var showPushes = false
    @State private var confettiTrigger = 0

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

                // Push count and par
                VStack(spacing: 4) {
                    Text("\(pushCount) Pushes")
                        .font(.system(size: pushFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    if let par = parPushes {
                        Text("Par: \(par)")
                            .font(.system(size: pushFontSize * 0.85, weight: .medium, design: .rounded))
                            .foregroundStyle(pushCount <= par ? .green : .white.opacity(0.6))
                    }
                }
                .opacity(showPushes ? 1 : 0)
                .scaleEffect(showPushes ? 1 : 0.8)

                // Score
                VStack(spacing: 6) {
                    // Trophy + current score (visible immediately, then counts up)
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

                    // "+N" bonus badge (appears when counting starts)
                    Text("+\(scoreGained)")
                        .font(.system(size: scoreBonusFontSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.green)
                        .opacity(showBonus ? 1 : 0)
                        .scaleEffect(showBonus ? 1 : 0.3)
                        .offset(y: showBonus ? 0 : 10)
                }

                // Continue button
                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.8)
                .padding(.top, 8)
            }
            .padding(40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level complete. \(pushCount) pushes\(parPushes.map { ", par \($0)" } ?? ""). \(stars) of 3 stars. Score plus \(scoreGained), total \(totalScore).")
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
                .font(.system(size: starSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))

            // Filled star (only if earned)
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

    /// Orchestrates the timed celebration animation sequence.
    @MainActor
    private func runCelebrationSequence() async {
        // Reset animation state so the sequence plays correctly
        // when re-triggered (e.g. visionOS RealityKit attachments persist).
        showBackground = false
        showTitle = false
        revealedStars = 0
        showScore = false
        showBonus = false
        animatedScore = 0
        showButton = false
        showPushes = false

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

        // 5. Show push count
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showPushes = true
        }
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }

        // 6. Show score at the user's previous total first
        let startScore = totalScore - scoreGained
        animatedScore = startScore

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showScore = true
        }
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }

        // 6a. Pop in the "+N" bonus badge
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            showBonus = true
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        // 6b. Count up one point at a time using numericText transition
        let delayPerPoint: UInt64 = scoreGained <= 5 ? 120 : (scoreGained <= 8 ? 80 : 60)
        for nextScore in stride(from: startScore + 1, through: totalScore, by: 1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                animatedScore = nextScore
            }
            try? await Task.sleep(for: .milliseconds(delayPerPoint))
            guard !Task.isCancelled else { return }
        }

        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }

        // 7. Show continue button
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showButton = true
        }
    }

    // MARK: - Platform-Adaptive Sizing

    private var titleFontSize: CGFloat {
        #if os(visionOS)
        42
        #elseif os(tvOS)
        52
        #else
        32
        #endif
    }

    private var starSize: CGFloat {
        #if os(visionOS)
        60
        #elseif os(tvOS)
        70
        #else
        48
        #endif
    }

    private var starSpacing: CGFloat {
        #if os(visionOS)
        24
        #elseif os(tvOS)
        28
        #else
        16
        #endif
    }

    private var scoreBonusFontSize: CGFloat {
        #if os(visionOS)
        36
        #elseif os(tvOS)
        40
        #else
        28
        #endif
    }

    private var pushFontSize: CGFloat {
        #if os(visionOS)
        24
        #elseif os(tvOS)
        28
        #else
        18
        #endif
    }

    private var totalScoreFontSize: CGFloat {
        #if os(visionOS)
        28
        #elseif os(tvOS)
        32
        #else
        22
        #endif
    }
}

// MARK: - ConfettiOverlay

/// A pure-SwiftUI confetti particle system using Canvas + TimelineView.
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

                    // Physics: parabolic fall + horizontal drift + wobble
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
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: -particle.height / 2))
                        path.addLine(to: CGPoint(x: particle.width / 2, y: particle.height / 2))
                        path.addLine(to: CGPoint(x: -particle.width / 2, y: particle.height / 2))
                        path.closeSubpath()
                        ctx.fill(path, with: .color(particle.color))
                    }
                }
            }
        }
        .onChange(of: trigger) {
            spawnBurst()
        }
    }

    /// Spawns a burst of confetti particles from the top-center area.
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

        // Cleanup old particles after longest lifetime
        Task {
            try? await Task.sleep(for: .seconds(5))
            particles.removeAll { particle in
                Date.timeIntervalSinceReferenceDate - particle.birthTime > particle.lifetime
            }
        }
    }
}

// MARK: - Confetti Particle Model

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
