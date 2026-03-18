// AnimationService.swift
// Manages player animations and visual effects like fireworks.

import Foundation
import RealityKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - AnimationService

/// Service responsible for managing player animations and visual effects.
/// Provides centralized control for character animations and particle effects.
/// Uses @Observable for fine-grained property tracking.
@MainActor
@Observable
final class AnimationService {

    // MARK: - Animation Keys

    /// Player animation names used by gameplay.
    private enum PlayerAnimationKey {
        static let idle = "idleAnimation"
        static let walking = "walkingAnimation"
        static let pushing = "pushingAnimation"
        static let stuck = "stuckAnimation"
        static let puzzleSolved = "puzzleSolvedAnimation"
    }

    // MARK: - Properties

    /// Current animation playback controller for managing animation state.
    var playerAnimationController: AnimationPlaybackController?

    /// Reference to the main scene for finding animation entities.
    @ObservationIgnored
    private weak var scene: Entity?

    /// Current player animation entity resolved in the scene.
    @ObservationIgnored
    private var cachedPlayerAnimationEntity: Entity?

    /// Cached player animation resources loaded once during configure.
    @ObservationIgnored
    private var idleAnimationResource: AnimationResource?
    @ObservationIgnored
    private var walkingAnimationResource: AnimationResource?
    @ObservationIgnored
    private var pushingAnimationResource: AnimationResource?
    @ObservationIgnored
    private var stuckAnimationResource: AnimationResource?
    @ObservationIgnored
    private var puzzleSolvedAnimationResource: AnimationResource?

    /// Cached box animation library for future use (if present in the scene assets).
    @ObservationIgnored
    private var cachedBoxAnimations: AnimationLibraryComponent.AnimationCollection?
    
    // MARK: - Configuration
    
    /// Sets the scene reference for animation entity lookups.
    /// Call this after the RealityKit scene is loaded.
    /// - Parameter scene: The main pushbox scene entity.
    func configure(with scene: Entity?) {
        self.scene = scene
        preloadAnimationResources()
    }
    
    // MARK: - Player Animations
    
    /// Private helper that plays a preloaded player animation.
    /// - Parameters:
    ///   - animation: Preloaded animation resource.
    ///   - shouldRepeat: Whether to loop the animation.
    private func playAnimation(_ animation: AnimationResource?, shouldRepeat: Bool = false) {
        guard let playerEntity = resolvePlayerAnimationEntity(),
              let animation else { return }
        
        playerAnimationController?.stop()
        playerAnimationController = playerEntity.playAnimation(shouldRepeat ? animation.repeat() : animation)
    }
    
    /// Plays the idle standing animation once (non-repeating to avoid
    /// continuous GPU work when the scene is otherwise static).
    func playIdleAnimation() {
        playAnimation(idleAnimationResource, shouldRepeat: false)
    }
    
    /// Plays the walking animation once.
    func playWalkingAnimation() {
        playAnimation(walkingAnimationResource)
    }
    
    /// Plays the box pushing animation once.
    func playPushingAnimation() {
        playAnimation(pushingAnimationResource)
    }
    
    /// Plays the stuck/blocked animation once.
    func playStuckAnimation() {
        playAnimation(stuckAnimationResource)
    }
    
    /// Plays the puzzle solved celebration animation on loop.
    func playPuzzleSolvedAnimation() {
        playAnimation(puzzleSolvedAnimationResource, shouldRepeat: true)
    }
    
    // MARK: - Visual Effects
    
    /// Enables the fireworks particle emitter.
    func startFireworks() {
        scene?.findEntity(named: "ParticleEmitterFireworks")?.isEnabled = true
    }
    
    /// Disables the fireworks particle emitter.
    func stopFireworks() {
        scene?.findEntity(named: "ParticleEmitterFireworks")?.isEnabled = false
    }

    /// Recursively disables all smoke particle emitter entities within a hierarchy.
    ///
    /// The Reality Composer Pro scene embeds `SmokeParticleEmitter` entities inside
    /// Wall and Box templates. When a level is built these emitters auto-play.
    /// Call this after building a level to suppress the smoke effect (e.g. during
    /// solution playback where the visual noise is unwanted).
    /// - Parameter root: The root entity whose descendants are searched.
    func disableSmokeEmitters(in root: Entity) {
        var stack: [Entity] = [root]
        while let current = stack.popLast() {
            if current.name == "SmokeParticleEmitter" {
                current.isEnabled = false
            }
            stack.append(contentsOf: current.children)
        }
    }

    // MARK: - Cache Helpers

    /// Preloads player and box animation resources once per scene configure.
    private func preloadAnimationResources() {
        cachedPlayerAnimationEntity = nil
        idleAnimationResource = nil
        walkingAnimationResource = nil
        pushingAnimationResource = nil
        stuckAnimationResource = nil
        puzzleSolvedAnimationResource = nil
        cachedBoxAnimations = nil

        guard let scene else { return }

        if let playerEntity = scene.findEntity(named: "playerAnimations") {
            cachedPlayerAnimationEntity = playerEntity
            cachePlayerAnimations(from: playerEntity)
        }

        cacheBoxAnimations(from: scene)
    }

    /// Resolves the currently active player animation entity, refreshing cache if needed.
    private func resolvePlayerAnimationEntity() -> Entity? {
        if let cached = cachedPlayerAnimationEntity, isInActiveScene(cached) {
            return cached
        }
        guard let entity = scene?.findEntity(named: "playerAnimations") else { return nil }
        cachedPlayerAnimationEntity = entity
        if idleAnimationResource == nil ||
            walkingAnimationResource == nil ||
            pushingAnimationResource == nil ||
            stuckAnimationResource == nil ||
            puzzleSolvedAnimationResource == nil {
            cachePlayerAnimations(from: entity)
        }
        return entity
    }

    /// Caches all known player animations for direct access during gameplay.
    private func cachePlayerAnimations(from playerEntity: Entity) {
        guard let animationLibrary = playerEntity.components[AnimationLibraryComponent.self] else { return }
        idleAnimationResource = animationLibrary.animations[PlayerAnimationKey.idle]
        walkingAnimationResource = animationLibrary.animations[PlayerAnimationKey.walking]
        pushingAnimationResource = animationLibrary.animations[PlayerAnimationKey.pushing]
        stuckAnimationResource = animationLibrary.animations[PlayerAnimationKey.stuck]
        puzzleSolvedAnimationResource = animationLibrary.animations[PlayerAnimationKey.puzzleSolved]
    }

    /// Caches the first box-related animation library if present in the scene.
    private func cacheBoxAnimations(from scene: Entity) {
        guard let boxRoot = scene.findEntity(named: "Box") else { return }
        if let boxLibrary = boxRoot.components[AnimationLibraryComponent.self] {
            cachedBoxAnimations = boxLibrary.animations
            return
        }
        guard let animatedBoxDescendant = firstEntityWithAnimationLibrary(in: boxRoot),
              let boxLibrary = animatedBoxDescendant.components[AnimationLibraryComponent.self] else {
            return
        }
        cachedBoxAnimations = boxLibrary.animations
    }

    /// Finds the first descendant that has an AnimationLibraryComponent.
    private func firstEntityWithAnimationLibrary(in root: Entity) -> Entity? {
        var stack: [Entity] = [root]
        while let current = stack.popLast() {
            if current.components[AnimationLibraryComponent.self] != nil {
                return current
            }
            stack.append(contentsOf: current.children)
        }
        return nil
    }

    /// Returns true when an entity is still attached somewhere under the active scene.
    private func isInActiveScene(_ entity: Entity) -> Bool {
        guard let scene else { return false }
        var current: Entity? = entity
        while let node = current {
            if node === scene { return true }
            current = node.parent
        }
        return false
    }
    
    // MARK: - Material Updates
    
    /// Updates a box entity's visual appearance based on slot status.
    ///
    /// Sets the `boxEmissiveColor` ShaderGraph parameter to red when the box
    /// is on a slot (arrived) or black otherwise.  `ShaderGraphMaterial` is
    /// available on visionOS 1+, iOS 18+, and macOS 15+, so a single code
    /// path works across all supported platforms.
    ///
    /// - Parameters:
    ///   - box: The box entity to update.
    ///   - isOnSlot: Whether the box is currently on a slot (arrived).
    func updateBoxMaterial(on box: Entity, isOnSlot: Bool) {
        guard var modelComponent = box.components[ModelComponent.self],
              var shaderGraphMaterial = modelComponent.materials.first as? ShaderGraphMaterial else {
            return
        }
        
        // Red when on slot (arrived), black otherwise
        #if canImport(UIKit)
        let color: UIColor = isOnSlot ? .red : .black
        #else
        let color: NSColor = isOnSlot ? .red : .black
        #endif
        
        do {
            try shaderGraphMaterial.setParameter(name: "boxEmissiveColor", value: .color(color))
            modelComponent.materials = [shaderGraphMaterial]
            box.components.set(modelComponent)
        } catch {
            AppLogger.animation.error("Failed to update box material: \(error.localizedDescription)")
        }
    }
}
