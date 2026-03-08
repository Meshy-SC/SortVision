import RealityKit
import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Central coordinator for the 3D puzzle game.
///
/// Replaces `GameScene` (SpriteKit). Manages the RealityKit entity hierarchy,
/// level loading, tube layout, tap interaction, pour logic, and win detection.
///
/// ## Architecture
/// - Owns a root `Entity` that is added to the `RealityView`
/// - `TubeEntity` children represent each tube
/// - Game logic (select → pour → win-check) mirrors the original SpriteKit flow
/// - Communicates results back to SwiftUI via closures (same pattern as GameScene)
@MainActor
final class GameScene3D: ObservableObject {

    // MARK: - Configuration

    /// The level data for this scene.
    var level: Level?

    /// Difficulty mode — passed through on completion.
    var gameMode: GameMode = .easy

    /// Whether to reduce motion (accessibility).
    var reduceMotion: Bool = false

    // MARK: - Callbacks (bridge to SwiftUI)

    var onLevelComplete: (() -> Void)?
    var onSaveProgress: ((GameMode, Int) -> Void)?

    // MARK: - Scene Root

    /// The root entity for the entire 3D scene. Add this to a `RealityView`.
    let rootEntity = Entity()

    // MARK: - Game State

    private(set) var holders: [TubeEntity] = []
    private var isTransferring = false
    private var gameState: GameState = .idle

    /// Horizontal spacing between tube centers (meters).
    private let holderSpacing: Float = 0.08

    enum GameState {
        case idle, playing, over
    }

    // MARK: - Scene Setup

    /// Call once after setting `level` to build the 3D scene.
    func setup() {
        rootEntity.name = "GameRoot"
        addLighting()
        loadLevel()
        gameState = .playing
    }

    // MARK: - Lighting

    /// Adds ambient and directional lighting so the glass and liquids look good.
    private func addLighting() {
        // Key directional light — from above-front
        let directionalLight = Entity()
        directionalLight.name = "KeyLight"
        var directional = DirectionalLightComponent()
        directional.intensity = 2500
        directional.color = .white
        directionalLight.components.set(directional)
        directionalLight.orientation = simd_quatf(
            angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0)
        )
        directionalLight.position = SIMD3<Float>(0, 0.5, 0.3)
        rootEntity.addChild(directionalLight)

        // Softer fill light from the side
        let fillLight = Entity()
        fillLight.name = "FillLight"
        var fill = DirectionalLightComponent()
        fill.intensity = 800
        fill.color = .init(white: 0.8, alpha: 1)
        fillLight.components.set(fill)
        fillLight.orientation = simd_quatf(
            angle: -.pi / 6, axis: SIMD3<Float>(0, 0, 1)
        )
        fillLight.position = SIMD3<Float>(-0.3, 0.3, 0)
        rootEntity.addChild(fillLight)
    }

    // MARK: - Level Loading

    /// Creates tube entities from level data.
    func loadLevel() {
        guard let level else { return }

        let holderCount = level.columns.count
        let positions = positionsForHolders(count: holderCount)
        let liquidSegments = level.compressedLiquidSegments

        for i in 0..<holderCount {
            let tube = TubeEntity()
            tube.holderIndex = i
            tube.position = positions[i]
            tube.populate(with: liquidSegments[i])
            rootEntity.addChild(tube)
            holders.append(tube)
        }
    }

    // MARK: - Layout

    /// Calculates tube positions in 3D space. Single row for ≤6, two rows otherwise.
    /// Returns positions in the XZ plane (Y=0), matching the RealityKit convention.
    private func positionsForHolders(count: Int) -> [SIMD3<Float>] {
        if count <= 6 {
            let totalWidth = Float(count - 1) * holderSpacing
            let startX = -totalWidth / 2
            return (0..<count).map { i in
                SIMD3<Float>(startX + Float(i) * holderSpacing, 0, 0)
            }
        }

        // Two rows
        let topRowCount = Int(ceil(Double(count) / 2.0))
        let bottomRowCount = count - topRowCount
        let rowSpacing: Float = TubeEntity.totalHeight + 0.05

        let frontZ: Float = rowSpacing / 2     // front row (closer to camera)
        let backZ: Float = -rowSpacing / 2     // back row

        // Back row (rendered behind)
        let topTotalWidth = Float(topRowCount - 1) * holderSpacing
        let topStartX = -topTotalWidth / 2
        let topPositions = (0..<topRowCount).map { i in
            SIMD3<Float>(topStartX + Float(i) * holderSpacing, 0, backZ)
        }

        // Front row
        let bottomTotalWidth = Float(bottomRowCount - 1) * holderSpacing
        let bottomStartX = -bottomTotalWidth / 2
        let bottomPositions = (0..<bottomRowCount).map { i in
            SIMD3<Float>(bottomStartX + Float(i) * holderSpacing, 0, frontZ)
        }

        return topPositions + bottomPositions
    }

    // MARK: - Tap Handling

    /// Called when a tube entity is tapped. Resolves which `TubeEntity`
    /// was hit and forwards to the selection logic.
    func handleTap(on entity: Entity) {
        guard gameState == .playing, !isTransferring else { return }

        // Walk up the entity hierarchy to find the TubeEntity
        var current: Entity? = entity
        while let c = current {
            if let tube = c as? TubeEntity {
                handleHolderSelection(tube)
                return
            }
            current = c.parent
        }

        // Tapped empty space — clear pending
        if let pending = holders.first(where: { $0.isPending }) {
            pending.clearPending()
        }
    }

    /// Called when the user taps empty space (no entity hit).
    func handleBackgroundTap() {
        guard gameState == .playing, !isTransferring else { return }
        if let pending = holders.first(where: { $0.isPending }) {
            pending.clearPending()
        }
    }

    /// Core interaction logic — mirrors `GameScene.handleHolderSelection(_:)`.
    private func handleHolderSelection(_ holder: TubeEntity) {
        let pendingHolder = holders.first(where: { $0.isPending })

        if let pending = pendingHolder, pending !== holder {
            // A different holder is pending — check if transfer is valid
            if holder.topLiquid == nil ||
                (pending.topLiquid?.groupId == holder.topLiquid?.groupId && !holder.isFull)
            {
                // Valid transfer — start pour
                isTransferring = true
                Task { @MainActor in
                    await pending.pourLiquid(to: holder)
                    isTransferring = false
                    checkWinCondition()
                }
            } else {
                // Invalid target — switch pending to tapped holder
                pending.clearPending()
                if !holder.isEmpty {
                    holder.startPending()
                }
            }
        } else if !holder.isEmpty {
            // No pending, or tapped same pending — toggle
            if holder.isPending {
                holder.clearPending()
            } else {
                holder.startPending()
            }
        }
    }

    // MARK: - Win Condition

    /// Checks if the puzzle is solved (mirrors original logic exactly).
    private func checkWinCondition() {
        let allSimple = holders.allSatisfy { $0.liquids.count <= 1 }
        guard allSimple else { return }

        let groupIds = holders.compactMap(\.liquids.first?.groupId)
        guard groupIds.count == Set(groupIds).count else { return }

        gameOver()
    }

    /// Handle level completion.
    private func gameOver() {
        guard gameState == .playing else { return }
        gameState = .over

        SoundManager3D.shared.play(.win)

        if let level {
            onSaveProgress?(gameMode, level.number)
        }

        if !reduceMotion {
            createConfettiEffect()
        }

        // Notify SwiftUI after delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            onLevelComplete?()
        }
    }

    // MARK: - Confetti Effect

    /// Creates a simple confetti particle burst using small colored entities.
    private func createConfettiEffect() {
        let colors = ColorPalette3D.colors

        for (index, rgba) in colors.enumerated() {
            let count = max(60 / colors.count, 1)
            for j in 0..<count {
                let confetti = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(0.006, 0.006, 0.002)),
                    materials: [{
                        var mat = PhysicallyBasedMaterial()
                        mat.baseColor = .init(tint: .init(
                            red: CGFloat(rgba.x),
                            green: CGFloat(rgba.y),
                            blue: CGFloat(rgba.z),
                            alpha: 1
                        ))
                        mat.roughness = .init(floatLiteral: 0.5)
                        return mat
                    }()]
                )
                confetti.name = "Confetti_\(index)_\(j)"

                // Random starting position above the scene
                let spreadX = Float.random(in: -0.25...0.25)
                let startY = Float.random(in: 0.35...0.50)
                let spreadZ = Float.random(in: -0.05...0.05)
                confetti.position = SIMD3<Float>(spreadX, startY, spreadZ)

                // Random rotation
                confetti.orientation = simd_quatf(
                    angle: Float.random(in: 0...(.pi * 2)),
                    axis: normalize(SIMD3<Float>(
                        Float.random(in: -1...1),
                        Float.random(in: -1...1),
                        Float.random(in: -1...1)
                    ))
                )

                rootEntity.addChild(confetti)

                // Animate falling
                let fallTarget = SIMD3<Float>(
                    spreadX + Float.random(in: -0.05...0.05),
                    -0.1,
                    spreadZ + Float.random(in: -0.03...0.03)
                )
                let spinRotation = simd_quatf(
                    angle: Float.random(in: (.pi * 2)...(.pi * 6)),
                    axis: normalize(SIMD3<Float>(
                        Float.random(in: -1...1),
                        Float.random(in: -1...1),
                        Float.random(in: 0.5...1)
                    ))
                )
                let fallTransform = Transform(
                    scale: confetti.scale,
                    rotation: spinRotation,
                    translation: fallTarget
                )
                let duration = Double.random(in: 2.0...3.5)
                confetti.move(
                    to: fallTransform,
                    relativeTo: confetti.parent,
                    duration: duration,
                    timingFunction: .easeIn
                )

                // Remove after animation
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(duration + 0.5))
                    confetti.removeFromParent()
                }
            }
        }
    }

    // MARK: - Restart

    /// Tears down and rebuilds the level.
    func restart() {
        for holder in holders {
            holder.removeFromParent()
        }
        holders.removeAll()
        isTransferring = false
        gameState = .playing

        // Remove confetti
        rootEntity.children
            .filter { $0.name.hasPrefix("Confetti_") }
            .forEach { $0.removeFromParent() }

        loadLevel()
    }
}
