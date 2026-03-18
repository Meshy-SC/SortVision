// ServiceProtocols.swift
// Protocol abstractions for game services, enabling dependency injection and mock-based testing.
//
// Each protocol defines the public contract of a service. The concrete implementations
// (AudioService, AnimationService, ProgressService) conform to these protocols.
// Tests can substitute lightweight mock conformances via AppModel's explicit-injection init.

import Foundation
import RealityKit

// MARK: - AudioServiceProtocol

/// Defines the public contract for audio playback management.
///
/// Conformers provide methods to play/stop individual sound effects
/// and background music. The concrete implementation is `AudioService`.
@MainActor
protocol AudioServiceProtocol: AnyObject {
    
    /// Sets the RealityKit scene reference for entity-based audio lookups.
    func configure(with scene: Entity?)
    
    // MARK: Playback
    
    func playWalkAudio()
    func playPushBoxAudio()
    func playArrivalAudio()
    func playStuckAudio()
    func playPuzzleAudio()
    func stopPuzzleAudio()
    func playPuzzleSolvedAudio()
    func playUndoAudio()
    func playFireworksAudio()
    
    // MARK: Toggle State (read-only from protocol perspective)
    
    var isPuzzleAudioEnabled: Bool { get set }
    var isWalkAudioEnabled: Bool { get set }
    var isPushAudioEnabled: Bool { get set }
    var isUndoAudioEnabled: Bool { get set }
    var isFireworksAudioEnabled: Bool { get set }
    var isArrivalAudioEnabled: Bool { get set }
    var isPuzzleSolvedAudioEnabled: Bool { get set }
    var isStuckAudioEnabled: Bool { get set }
}

// MARK: - AnimationServiceProtocol

/// Defines the public contract for player animations and visual effects.
///
/// Conformers provide methods to play character animations, manage particle
/// effects, and update box material appearance. The concrete implementation
/// is `AnimationService`.
@MainActor
protocol AnimationServiceProtocol: AnyObject {
    
    /// Current animation playback controller.
    var playerAnimationController: AnimationPlaybackController? { get set }
    
    /// Sets the RealityKit scene reference for entity lookups.
    func configure(with scene: Entity?)
    
    // MARK: Player Animations
    
    func playIdleAnimation()
    func playWalkingAnimation()
    func playPushingAnimation()
    func playStuckAnimation()
    func playPuzzleSolvedAnimation()
    
    // MARK: Visual Effects
    
    func startFireworks()
    func stopFireworks()
    func disableSmokeEmitters(in root: Entity)
    
    // MARK: Material Updates
    
    func updateBoxMaterial(on box: Entity, isOnSlot: Bool)
}

// MARK: - ProgressServiceProtocol

/// Defines the public contract for game progress tracking and persistence.
///
/// Conformers manage level completion recording, push counting, star ratings,
/// and aggregated statistics. The concrete implementation is `ProgressService`.
@MainActor
protocol ProgressServiceProtocol: AnyObject {
    
    /// Progress dictionary: [WorldName: [LevelIndex: LevelProgress]].
    var progress: [String: [Int: LevelProgress]] { get set }
    
    /// Current level push count (resets on level load).
    var currentLevelPushes: Int { get set }
    
    /// Overall completion percentage across all worlds.
    var overallProgress: Double { get }
    
    /// Total score across all completed levels.
    var globalScore: Int { get }
    
    /// Maximum possible score.
    var maximumGlobalScore: Int { get }
    
    /// Score for a single world.
    func worldScore(for worldName: String) -> Int
    
    /// Maximum possible score for a single world.
    func maximumWorldScore(for worldName: String) -> Int
    
    // MARK: Push Count Management
    
    func incrementPushCount()
    func decrementPushCount()
    func resetPushCount()
    
    // MARK: Level Completion
    
    func completeLevel(for world: World, levelIndex: Int)
    
    // MARK: Query Methods
    
    func completedCount(for worldName: String) -> Int
    func isLevelCompleted(worldName: String, levelIndex: Int) -> Bool
    func starRating(worldName: String, levelIndex: Int) -> Int
    func optimalPushes(for world: World?, levelIndex: Int?) -> Int?
    
    // MARK: Progression & Unlocking
    
    func isWorldUnlocked(_ world: World) -> Bool
    func isLevelUnlocked(_ levelIndex: Int, in world: World) -> Bool
    func completionsNeededForNextWorld(after worldName: String) -> Int?
    func completionsNeededForNextGroup(groupSize: Int) -> Int
    func firstLockedLevelIndex(in world: World) -> Int?
    func nextPlayableLevel(in world: World) -> Int?
    func unlockRequirement(forWorld world: World) -> String?
    func unlockRequirement(forLevel levelIndex: Int, in world: World) -> String?
    
    // MARK: Persistence
    
    func saveProgress()
    func loadProgress()
    func resetAllProgress()
}

// MARK: - Protocol Conformances

// The concrete service classes already implement all required methods.
// These empty extensions simply declare conformance.

extension AudioService: AudioServiceProtocol {}
extension AnimationService: AnimationServiceProtocol {}
extension ProgressService: ProgressServiceProtocol {}
