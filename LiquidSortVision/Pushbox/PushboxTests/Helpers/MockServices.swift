// MockServices.swift
// Mock service implementations for testing game logic without RealityKit scene.

import Testing
import Foundation
import RealityKit
@testable import Pushbox

// MARK: - MockAudioService

/// Mock audio service that records method calls for verification.
/// Conforms to `AudioServiceProtocol` for injection via `AppModel`.
@MainActor
final class MockAudioService: AudioServiceProtocol {

    /// Ordered list of method names called on this mock.
    var calls: [String] = []

    // MARK: - Toggle Properties

    var isPuzzleAudioEnabled: Bool = true
    var isWalkAudioEnabled: Bool = true
    var isPushAudioEnabled: Bool = true
    var isUndoAudioEnabled: Bool = true
    var isFireworksAudioEnabled: Bool = true
    var isArrivalAudioEnabled: Bool = true
    var isPuzzleSolvedAudioEnabled: Bool = true
    var isStuckAudioEnabled: Bool = true

    // MARK: - Protocol Methods

    func configure(with scene: Entity?) { calls.append("configure") }
    func playWalkAudio() { calls.append("playWalkAudio") }
    func playPushBoxAudio() { calls.append("playPushBoxAudio") }
    func playArrivalAudio() { calls.append("playArrivalAudio") }
    func playStuckAudio() { calls.append("playStuckAudio") }
    func playPuzzleAudio() { calls.append("playPuzzleAudio") }
    func stopPuzzleAudio() { calls.append("stopPuzzleAudio") }
    func playPuzzleSolvedAudio() { calls.append("playPuzzleSolvedAudio") }
    func playUndoAudio() { calls.append("playUndoAudio") }
    func playFireworksAudio() { calls.append("playFireworksAudio") }
}

// MARK: - MockAnimationService

/// Mock animation service that records method calls for verification.
/// Conforms to `AnimationServiceProtocol` for injection via `AppModel`.
@MainActor
final class MockAnimationService: AnimationServiceProtocol {

    /// Ordered list of method names called on this mock.
    var calls: [String] = []

    var playerAnimationController: AnimationPlaybackController?

    // MARK: - Protocol Methods

    func configure(with scene: Entity?) { calls.append("configure") }
    func playIdleAnimation() { calls.append("playIdleAnimation") }
    func playWalkingAnimation() { calls.append("playWalkingAnimation") }
    func playPushingAnimation() { calls.append("playPushingAnimation") }
    func playStuckAnimation() { calls.append("playStuckAnimation") }
    func playPuzzleSolvedAnimation() { calls.append("playPuzzleSolvedAnimation") }
    func startFireworks() { calls.append("startFireworks") }
    func stopFireworks() { calls.append("stopFireworks") }
    func disableSmokeEmitters(in root: Entity) { calls.append("disableSmokeEmitters") }
    func updateBoxMaterial(on box: Entity, isOnSlot: Bool) {
        calls.append("updateBoxMaterial(isOnSlot:\(isOnSlot))")
    }
}
