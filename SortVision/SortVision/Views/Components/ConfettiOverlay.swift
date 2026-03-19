import SwiftUI

// MARK: - ConfettiOverlay

/// Particle-based confetti celebration effect.
///
/// Renders a burst of colourful shapes (rectangles, circles, triangles)
/// that launch upward and fall with gravity, wobble, and rotation.
/// Triggered by incrementing the `trigger` binding.
///
/// Used by ``LevelCompletionOverlay`` to celebrate level completion.
/// Designed as a standalone reusable component so it can be added
/// to any view that needs a celebration effect.
///
/// ## Usage
/// ```swift
/// @State private var confettiBurstToken = 0
///
/// ConfettiOverlay(trigger: confettiBurstToken)
///     .ignoresSafeArea()
///     .allowsHitTesting(false)
///
/// // To trigger:
/// confettiBurstToken += 1
/// ```
struct ConfettiOverlay: View {
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
        .accessibilityHidden(true)
    }

    /// Spawns a burst of 80 randomly configured confetti particles.
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

// MARK: - Confetti Particle Model

/// Internal data model for a single confetti particle.
private struct ConfettiParticle: Identifiable, Sendable {
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

// MARK: - Confetti Shape

/// The three confetti particle shapes rendered by ``ConfettiOverlay``.
private enum ConfettiShape: CaseIterable, Sendable {
    case rectangle, circle, triangle
}
