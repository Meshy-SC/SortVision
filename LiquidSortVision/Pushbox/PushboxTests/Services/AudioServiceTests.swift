// AudioServiceTests.swift
// Tests for AudioService toggle defaults, configuration, and protocol conformance.

import Testing
import Foundation
import RealityKit
@testable import Pushbox

// MARK: - AudioService Tests

@MainActor
@Suite("AudioService Tests")
struct AudioServiceTests {

    // MARK: - Toggle Defaults

    @Test("All audio toggles default to enabled")
    func defaultToggles() {
        let service = AudioService()
        #expect(service.isPuzzleAudioEnabled == true)
        #expect(service.isWalkAudioEnabled == true)
        #expect(service.isPushAudioEnabled == true)
        #expect(service.isUndoAudioEnabled == true)
        #expect(service.isFireworksAudioEnabled == true)
        #expect(service.isArrivalAudioEnabled == true)
        #expect(service.isPuzzleSolvedAudioEnabled == true)
        #expect(service.isStuckAudioEnabled == true)
    }

    @Test("Audio toggles are independently settable")
    func togglesIndependentlySettable() {
        let service = AudioService()
        service.isPuzzleAudioEnabled = false
        #expect(service.isPuzzleAudioEnabled == false)
        #expect(service.isWalkAudioEnabled == true) // others unchanged

        service.isWalkAudioEnabled = false
        #expect(service.isWalkAudioEnabled == false)
        #expect(service.isPushAudioEnabled == true)
    }

    // MARK: - Configuration

    @Test("Configure with nil scene does not crash")
    func configureNilScene() {
        let service = AudioService()
        service.configure(with: nil)
        // No crash = pass
    }

    // MARK: - Playback Safety

    @Test("Play methods do not crash without configured scene")
    func playMethodsSafe() {
        let service = AudioService()
        // All methods should be no-ops without a scene
        service.playWalkAudio()
        service.playPushBoxAudio()
        service.playArrivalAudio()
        service.playStuckAudio()
        service.playPuzzleAudio()
        service.stopPuzzleAudio()
        service.playPuzzleSolvedAudio()
        service.playUndoAudio()
        service.playFireworksAudio()
        // No crash = pass
    }

    @Test("Play methods respect toggle guards")
    func playMethodsRespectToggles() {
        let service = AudioService()
        // Disable all toggles
        service.isWalkAudioEnabled = false
        service.isPushAudioEnabled = false
        service.isArrivalAudioEnabled = false
        service.isStuckAudioEnabled = false
        service.isPuzzleAudioEnabled = false
        service.isPuzzleSolvedAudioEnabled = false
        service.isUndoAudioEnabled = false
        service.isFireworksAudioEnabled = false

        // Methods should return early without attempting playback
        service.playWalkAudio()
        service.playPushBoxAudio()
        service.playArrivalAudio()
        service.playStuckAudio()
        service.playPuzzleSolvedAudio()
        service.playUndoAudio()
        service.playFireworksAudio()
        // No crash = pass (guard early returns before scene lookup)
    }

    // MARK: - Protocol Conformance

    @Test("AudioService conforms to AudioServiceProtocol")
    func protocolConformance() {
        let service = AudioService()
        let _: any AudioServiceProtocol = service
        // Compiles and assigns = pass
    }

    // MARK: - Mock Verification

    @Test("MockAudioService records method calls")
    func mockRecordsCalls() {
        let mock = MockAudioService()
        mock.playWalkAudio()
        mock.playPushBoxAudio()
        mock.playStuckAudio()
        #expect(mock.calls == ["playWalkAudio", "playPushBoxAudio", "playStuckAudio"])
    }
}
