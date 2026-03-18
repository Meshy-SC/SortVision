// GameSceneView+DropAnimation.swift
// Level entrance drop animation — every entity falls from above with a
// diagonal-wave reveal, physics-based freefall, and impact bounce.
//
// Inspired by the board-reveal patterns in Lara Croft GO, Hitman GO,
// Captain Toad, and Monument Valley: a diagonal sweep assembles the
// level tile by tile, each piece bouncing on impact for tactile weight.
// The player always lands last as a dramatic entrance.

import SwiftUI
import RealityKit

// MARK: - Drop Animation Extension

extension GameSceneView {

    // MARK: - Drop Configuration

    /// Per-entity-type drop parameters.
    private struct DropConfig {
        let height: Float
        let bounceHeight: Float
    }

    /// Returns drop height and bounce height tuned to the entity type.
    ///
    /// - Slots are flat ground tiles — low drop, subtle bounce.
    /// - Walls are heavy geometry — medium-high drop, small bounce.
    /// - Boxes are movable objects — medium drop, moderate bounce.
    /// - Player is the star — highest drop, biggest bounce.
    private static func dropConfig(for entity: Entity) -> DropConfig {
        switch entity.name {
        case "Slot":   DropConfig(height: 0.15,
                                  bounceHeight: 0.004)
        case "Box":    DropConfig(height: 0.30 + .random(in: -0.06...0.06),
                                  bounceHeight: 0.012)
        case "Player": DropConfig(height: 0.45,
                                  bounceHeight: 0.018)
        default:       DropConfig(height: 0.35 + .random(in: -0.08...0.08),
                                  bounceHeight: 0.008)
        }
    }

    // MARK: - Entity Ordering

    /// Returns all level children sorted in diagonal-wave order for the drop
    /// sequence, with the player always last.
    ///
    /// The diagonal index `(row + column)` groups entities on the same
    /// top-left → bottom-right diagonal. Sweeping ascending diagonals
    /// creates a wave that builds the level from one corner to the
    /// opposite — a pattern borrowed from Lara Croft GO's tile reveals.
    ///
    /// - Parameter root: The level root entity whose children are sorted.
    /// - Returns: All entities in drop order.
    func entitiesInDropOrder(root: Entity) -> [Entity] {
        var entities: [Entity] = []
        var player: Entity?

        for child in root.children {
            // Skip entities disabled during level construction (e.g. slots
            // hidden under arrived boxes in the "*" case). They must stay hidden.
            guard child.isEnabled else { continue }

            if child.name == "Player" {
                player = child
            } else {
                entities.append(child)
            }
        }

        let cellSize = GameLayout.cellSize
        entities.sort { a, b in
            let aCol = Int(round(a.position.x / cellSize))
            let aRow = Int(round(a.position.z / cellSize))
            let bCol = Int(round(b.position.x / cellSize))
            let bRow = Int(round(b.position.z / cellSize))
            let aDiag = aRow + aCol
            let bDiag = bRow + bCol
            if aDiag != bDiag { return aDiag < bDiag }
            return aCol < bCol
        }

        if let player { entities.append(player) }
        return entities
    }

    // MARK: - Main Orchestrator

    /// Animates every level entity dropping in with a diagonal-wave reveal,
    /// physics freefall, and impact bounce.
    ///
    /// - Parameters:
    ///   - root: The level root entity containing all level children.
    ///   - reduceMotion: When `true`, entities appear instantly with no animation.
    func performDropAnimation(on root: Entity, reduceMotion: Bool) {
        dropAnimationTask?.cancel()

        // Reduce motion: reveal instantly
        if reduceMotion {
            root.isEnabled = true
            isLevelReady = true
            appModel.animationService.playIdleAnimation()
            if appModel.isPuzzleAudioEnabled {
                appModel.audioService.stopPuzzleAudio()
                appModel.audioService.playPuzzleAudio()
            }
            return
        }

        dropAnimationTask = Task { @MainActor in
            isAnimating = true
            appModel.animationService.disableSmokeEmitters(in: root)

            let entities = entitiesInDropOrder(root: root)

            // Build per-entity config and raise each entity above the level
            var finalPositions: [Entity: SIMD3<Float>] = [:]
            var configs: [Entity: DropConfig] = [:]

            for entity in entities {
                let config = Self.dropConfig(for: entity)
                configs[entity] = config
                finalPositions[entity] = entity.position
                entity.position.y += config.height
                entity.isEnabled = false
            }

            // Enable root — individual children are still hidden.
            // The loading overlay is suppressed by the dropAnimationTask != nil
            // check, so we don't need to set isLevelReady = true yet. That flag
            // stays false until the animation finishes, which correctly disables
            // gameplay buttons (solution, undo, D-Pad) per Apple HIG.
            root.isEnabled = true

            // Start puzzle audio alongside the first drop
            if appModel.isPuzzleAudioEnabled {
                appModel.audioService.stopPuzzleAudio()
                appModel.audioService.playPuzzleAudio()
            }

            // Drop each entity with stagger
            for (index, entity) in entities.enumerated() {
                guard !Task.isCancelled else { break }

                guard let finalPosition = finalPositions[entity],
                      let config = configs[entity] else { continue }

                entity.isEnabled = true

                let fallDuration = GameLayout.freefallDuration(for: config.height)
                let bounceHeight = config.bounceHeight

                // Fire-and-forget per-entity drop + bounce sequence.
                // Each entity independently completes its own animation arc.
                Task { @MainActor in
                    // ① Freefall to ground with easeIn (≈ constant-gravity t² curve)
                    entity.move(
                        to: Transform(scale: entity.transform.scale,
                                      rotation: entity.transform.rotation,
                                      translation: finalPosition),
                        relativeTo: entity.parent,
                        duration: fallDuration,
                        timingFunction: .easeIn
                    )
                    try? await Task.sleep(for: .seconds(fallDuration))

                    // ② Impact — enable the entity's embedded smoke emitters
                    //    (designed in Reality Composer Pro). Their initial burst
                    //    serves as the landing effect.
                    enableSmokeEmitters(in: entity)

                    // ③ Bounce up (rebound)
                    let bouncePos = SIMD3<Float>(
                        finalPosition.x,
                        finalPosition.y + bounceHeight,
                        finalPosition.z
                    )
                    entity.move(
                        to: Transform(scale: entity.transform.scale,
                                      rotation: entity.transform.rotation,
                                      translation: bouncePos),
                        relativeTo: entity.parent,
                        duration: GameLayout.dropBounceUpDuration,
                        timingFunction: .easeOut
                    )
                    try? await Task.sleep(for: .seconds(GameLayout.dropBounceUpDuration))

                    // ④ Settle back to final position
                    entity.move(
                        to: Transform(scale: entity.transform.scale,
                                      rotation: entity.transform.rotation,
                                      translation: finalPosition),
                        relativeTo: entity.parent,
                        duration: GameLayout.dropBounceDownDuration,
                        timingFunction: .easeIn
                    )
                }

                // Stagger delay between entities (skip after last)
                if index < entities.count - 1 {
                    try? await Task.sleep(for: .seconds(GameLayout.dropStaggerDelay))
                }
            }

            // Handle cancellation — snap all entities to final positions
            if Task.isCancelled {
                for entity in entities {
                    if let finalPosition = finalPositions[entity] {
                        entity.position = finalPosition
                        entity.isEnabled = true
                    }
                }
                isAnimating = false
                isLevelReady = true
                dropAnimationTask = nil
                appModel.animationService.playIdleAnimation()
                return
            }

            // Wait for the last entity's full sequence (fall + bounce) to finish.
            // The main loop has already slept through all stagger delays, so the
            // last entity JUST started its drop.
            if let lastEntity = entities.last, let lastConfig = configs[lastEntity] {
                let lastFall = GameLayout.freefallDuration(for: lastConfig.height)
                let bounce = GameLayout.dropBounceUpDuration + GameLayout.dropBounceDownDuration
                try? await Task.sleep(for: .seconds(lastFall + bounce))
            }

            guard !Task.isCancelled else {
                isAnimating = false
                isLevelReady = true
                dropAnimationTask = nil
                appModel.animationService.playIdleAnimation()
                return
            }

            isAnimating = false
            isLevelReady = true
            dropAnimationTask = nil
            appModel.animationService.playIdleAnimation()
        }
    }

    // MARK: - Smoke Emitter Control

    /// Enables all `SmokeParticleEmitter` children within the given entity.
    ///
    /// The Reality Composer Pro scene embeds smoke emitters inside Wall and Box
    /// templates. They are disabled at the start of the drop animation to prevent
    /// them from playing during freefall. Re-enabling them on impact lets their
    /// designed burst serve as the landing effect.
    private func enableSmokeEmitters(in entity: Entity) {
        var stack: [Entity] = [entity]
        while let current = stack.popLast() {
            if current.name == "SmokeParticleEmitter" {
                current.isEnabled = true
            }
            stack.append(contentsOf: current.children)
        }
    }
}
