// AudioService.swift
// Manages audio playback for all game sounds including puzzle music and sound effects.

import Foundation
import SwiftUI
import RealityKit

// MARK: - AudioService

/// Service responsible for managing all audio playback in the game.
/// Provides centralized control for puzzle music and various sound effects.
/// Uses @Observable for fine-grained property tracking.
@MainActor
@Observable
final class AudioService {

    // MARK: - Audio Keys

    /// Named audio entities expected in the scene hierarchy.
    private enum AudioKey {
        static let walk = "playerWalkAudio"
        static let push = "pushBoxAudio"
        static let arrival = "arrivalAudio"
        static let stuck = "stuckAudio"
        static let puzzle = "puzzleAudio"
        static let puzzleSolved = "puzzleSolvedAudio"
        static let undo = "undoAudio"
        static let fireworks = "fireworksAudio"

        static let preloadList = [
            walk,
            push,
            arrival,
            stuck,
            puzzle,
            puzzleSolved,
            undo,
            fireworks
        ]
    }

    // MARK: - Audio Toggle Properties (persisted via @AppStorage)
    // @ObservationIgnored prevents @Observable from synthesizing conflicting
    // underscore-prefixed backing storage. @AppStorage handles its own
    // change propagation through SwiftUI's update cycle.

    @ObservationIgnored @AppStorage("puzzleAudioEnabled") var isPuzzleAudioEnabled: Bool = true
    @ObservationIgnored @AppStorage("walkAudioEnabled") var isWalkAudioEnabled: Bool = true
    @ObservationIgnored @AppStorage("pushAudioEnabled") var isPushAudioEnabled: Bool = true
    @ObservationIgnored @AppStorage("undoAudioEnabled") var isUndoAudioEnabled: Bool = true
    @ObservationIgnored @AppStorage("fireworksAudioEnabled") var isFireworksAudioEnabled: Bool = true
    @ObservationIgnored @AppStorage("arrivalAudioEnabled") var isArrivalAudioEnabled: Bool = true
    @ObservationIgnored @AppStorage("puzzleSolvedAudioEnabled") var isPuzzleSolvedAudioEnabled: Bool = true
    @ObservationIgnored @AppStorage("stuckAudioEnabled") var isStuckAudioEnabled: Bool = true

    // MARK: - Private Properties

    /// Reference to the main scene for finding audio entities.
    @ObservationIgnored
    private weak var scene: Entity?

    /// Cached emitter entity per audio key.
    @ObservationIgnored
    private var cachedAudioEntities: [String: Entity] = [:]

    /// Cached audio resource per audio key (loaded once during startup/configure).
    @ObservationIgnored
    private var cachedAudioResources: [String: AudioResource] = [:]
    
    // MARK: - Configuration
    
    /// Sets the scene reference for audio entity lookups.
    /// Call this after the RealityKit scene is loaded.
    /// - Parameter scene: The main pushbox scene entity.
    func configure(with scene: Entity?) {
        self.scene = scene
        preloadAudioResources()
    }
    
    // MARK: - Playback Methods
    
    /// Plays walking footstep audio if enabled.
    func playWalkAudio() {
        guard isWalkAudioEnabled else { return }
        playEntityAudio(AudioKey.walk)
    }
    
    /// Plays box push audio if enabled.
    func playPushBoxAudio() {
        guard isPushAudioEnabled else { return }
        playEntityAudio(AudioKey.push)
    }
    
    /// Plays box arrival on slot audio if enabled.
    func playArrivalAudio() {
        guard isArrivalAudioEnabled else { return }
        playEntityAudio(AudioKey.arrival)
    }
    
    /// Plays stuck/blocked movement audio if enabled.
    func playStuckAudio() {
        guard isStuckAudioEnabled else { return }
        playEntityAudio(AudioKey.stuck)
    }
    
    /// Stops any playing puzzle audio and starts fresh playback if enabled.
    func playPuzzleAudio() {
        guard isPuzzleAudioEnabled,
              let (entity, puzzleAudio) = resolveAudioEntry(for: AudioKey.puzzle) else { return }
        
        // Stop any in-flight audio to prevent overlaps
        entity.stopAllAudio()
        entity.playAudio(puzzleAudio)
    }
    
    /// Stops puzzle background music.
    func stopPuzzleAudio() {
        guard let entity = resolveAudioEntity(for: AudioKey.puzzle) else { return }
        entity.stopAllAudio()
    }
    
    /// Plays puzzle solved celebration audio if enabled.
    func playPuzzleSolvedAudio() {
        guard isPuzzleSolvedAudioEnabled else { return }
        playEntityAudio(AudioKey.puzzleSolved)
    }
    
    /// Plays undo action audio if enabled.
    func playUndoAudio() {
        guard isUndoAudioEnabled else { return }
        playEntityAudio(AudioKey.undo)
    }
    
    /// Plays fireworks celebration audio if enabled.
    func playFireworksAudio() {
        guard isFireworksAudioEnabled else { return }
        playEntityAudio(AudioKey.fireworks)
    }
    
    // MARK: - Private Helpers
    
    /// Plays audio from a named entity using its AudioLibraryComponent resource.
    /// Uses direct RealityKit `entity.playAudio()` — no entity cloning needed.
    /// Each call returns an independent `AudioPlaybackController`, so overlapping
    /// playback is handled automatically by RealityKit.
    private func playEntityAudio(_ entityName: String) {
        guard let (entity, resource) = resolveAudioEntry(for: entityName) else {
            AppLogger.audio.warning("Failed to play audio for: \(entityName)")
            return
        }
        entity.playAudio(resource)
    }

    /// Preloads all known audio resources during scene startup.
    /// This avoids first-play hitches and repeated component lookups.
    private func preloadAudioResources() {
        cachedAudioEntities.removeAll()
        cachedAudioResources.removeAll()
        guard let scene else { return }

        for key in AudioKey.preloadList {
            guard let entity = scene.findEntity(named: key),
                  let audioLibrary = entity.components[AudioLibraryComponent.self],
                  let resource = audioLibrary.resources.first?.value else {
                continue
            }
            cachedAudioEntities[key] = entity
            cachedAudioResources[key] = resource
        }
    }

    /// Resolves and caches the current emitter entity for an audio key.
    /// If a cached entity is no longer in the active scene (e.g. after level rebuild),
    /// it is refreshed from the scene hierarchy.
    private func resolveAudioEntity(for key: String) -> Entity? {
        if let cached = cachedAudioEntities[key], isInActiveScene(cached) {
            return cached
        }
        guard let entity = scene?.findEntity(named: key) else { return nil }
        cachedAudioEntities[key] = entity
        return entity
    }

    /// Resolves an audio emitter and its preloaded resource.
    /// Falls back to loading from `AudioLibraryComponent` once if the cache was missing.
    private func resolveAudioEntry(for key: String) -> (Entity, AudioResource)? {
        guard let entity = resolveAudioEntity(for: key) else { return nil }
        if let resource = cachedAudioResources[key] {
            return (entity, resource)
        }
        guard let audioLibrary = entity.components[AudioLibraryComponent.self],
              let resource = audioLibrary.resources.first?.value else {
            return nil
        }
        cachedAudioResources[key] = resource
        return (entity, resource)
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
}
