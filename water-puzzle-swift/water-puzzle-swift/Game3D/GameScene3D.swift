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

    /// Preferred horizontal spacing between tube centres (meters).
    /// Actual spacing may shrink for levels with many tubes.
    private let preferredSpacing: Float = 0.08

    /// Minimum spacing – tube diameter + a small gap so they never touch.
    private let minimumSpacing: Float = TubeEntity.outerWidth + 0.014

    /// Maximum total row width (meters) before the layout must shrink spacing.
    /// Tuned so tubes stay comfortably within the RealityView viewport.
    private let maxRowWidth: Float = 0.50

    /// Maximum tubes that fit in a single row before switching to two rows.
    private let maxPerSingleRow: Int = 7

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

    /// Height above each tube where its spotlight is placed (meters).
    private let spotlightHeight: Float = 0.25

    /// Adds a soft ambient fill light to the scene.
    /// Individual spotlights are added per tube in `loadLevel()`.
    private func addLighting() {
        // Soft directional fill so nothing is fully dark
        let fill = Entity()
        fill.name = "AmbientFill"
        var fillComp = DirectionalLightComponent()
        fillComp.intensity = 1500
        fillComp.color = .init(white: 0.9, alpha: 1)
        fill.components.set(fillComp)
        fill.orientation = simd_quatf(
            angle: -.pi / 6, axis: SIMD3<Float>(1, 0, 0)
        )
        fill.position = SIMD3<Float>(0, 0.5, 0.3)
        rootEntity.addChild(fill)
    }

    /// Creates a spotlight entity that shines downward onto a tube.
    /// Parented to the tube so it follows during pour animations.
    private func makeSpotlight(for tube: TubeEntity) -> Entity {
        let light = Entity()
        light.name = "Spotlight_\(tube.holderIndex)"

        var spot = SpotLightComponent()
        spot.intensity = 12000
        spot.color = .white
        spot.innerAngleInDegrees = 20
        spot.outerAngleInDegrees = 45
        spot.attenuationRadius = 0.6
        light.components.set(spot)

        // Position above tube centre, pointing straight down
        light.position = SIMD3<Float>(0, TubeEntity.totalHeight + spotlightHeight, 0)
        light.orientation = simd_quatf(
            angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0)
        )
        return light
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

            // Attach a personal spotlight — follows the tube during pour
            let spot = makeSpotlight(for: tube)
            tube.addChild(spot)

            rootEntity.addChild(tube)
            holders.append(tube)
        }
    }

    // MARK: - Layout

    /// Calculates tube positions in 3D space.
    ///
    /// Uses a single row when the tube count fits comfortably (`≤ maxPerSingleRow`).
    /// Beyond that, tubes are split across two rows with enough depth separation
    /// to avoid visual overlap under perspective projection.
    ///
    /// Spacing is adaptive: it shrinks from `preferredSpacing` towards
    /// `minimumSpacing` as the row grows, ensuring tubes never overlap.
    private func positionsForHolders(count: Int) -> [SIMD3<Float>] {
        guard count > 0 else { return [] }

        if count <= maxPerSingleRow {
            let spacing = spacingForRow(of: count)
            return singleRow(count: count, spacing: spacing, z: 0)
        }

        // Two rows — larger row goes in back so the front row doesn't obscure it.
        let backRowCount  = Int(ceil(Double(count) / 2.0))
        let frontRowCount = count - backRowCount

        let spacing = spacingForRow(of: max(backRowCount, frontRowCount))

        // Depth gap between rows — enough so the front row doesn't clip the back row.
        let rowDepth: Float = TubeEntity.totalHeight * 0.7 + 0.06
        let backZ:  Float = -rowDepth / 2
        let frontZ: Float =  rowDepth / 2

        let backPositions  = singleRow(count: backRowCount,  spacing: spacing, z: backZ)
        let frontPositions = singleRow(count: frontRowCount, spacing: spacing, z: frontZ)

        return backPositions + frontPositions
    }

    /// Returns the best spacing for a row of `n` tubes so the row fits within
    /// `maxRowWidth` while never going below `minimumSpacing`.
    private func spacingForRow(of n: Int) -> Float {
        guard n > 1 else { return preferredSpacing }
        let maxFit = maxRowWidth / Float(n - 1)
        return max(min(preferredSpacing, maxFit), minimumSpacing)
    }

    /// Builds an array of centred positions along the X-axis at a fixed Z depth.
    private func singleRow(count: Int, spacing: Float, z: Float) -> [SIMD3<Float>] {
        let totalWidth = Float(count - 1) * spacing
        let startX = -totalWidth / 2
        return (0..<count).map { i in
            SIMD3<Float>(startX + Float(i) * spacing, 0, z)
        }
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
