// AnimationServiceTests.swift
// Tests for AnimationService state, configuration, and protocol conformance.

import Testing
import Foundation
import RealityKit
@testable import Pushbox

// MARK: - AnimationService Tests

@MainActor
@Suite("AnimationService Tests")
struct AnimationServiceTests {

    @Test("Service initializes with nil animation controller")
    func initialState() {
        let service = AnimationService()
        #expect(service.playerAnimationController == nil)
    }

    @Test("Configure with nil scene does not crash")
    func configureNilScene() {
        let service = AnimationService()
        service.configure(with: nil)
    }

    @Test("Animation methods do not crash without configured scene")
    func animationMethodsSafe() {
        let service = AnimationService()
        service.playIdleAnimation()
        service.playWalkingAnimation()
        service.playPushingAnimation()
        service.playStuckAnimation()
        service.playPuzzleSolvedAnimation()
    }

    @Test("Fireworks methods do not crash without configured scene")
    func fireworksMethodsSafe() {
        let service = AnimationService()
        service.startFireworks()
        service.stopFireworks()
    }

    @Test("updateBoxMaterial does not crash with arbitrary entity")
    func updateBoxMaterialSafe() {
        let service = AnimationService()
        let entity = Entity()
        // Should not crash — guard on ModelComponent returns early
        service.updateBoxMaterial(on: entity, isOnSlot: true)
        service.updateBoxMaterial(on: entity, isOnSlot: false)
    }

    @Test("AnimationService conforms to AnimationServiceProtocol")
    func protocolConformance() {
        let service = AnimationService()
        let _: any AnimationServiceProtocol = service
    }

    // MARK: - Mock Verification

    @Test("MockAnimationService records method calls")
    func mockRecordsCalls() {
        let mock = MockAnimationService()
        mock.playIdleAnimation()
        mock.playPushingAnimation()
        mock.startFireworks()
        mock.stopFireworks()
        mock.updateBoxMaterial(on: Entity(), isOnSlot: true)
        #expect(mock.calls == [
            "playIdleAnimation",
            "playPushingAnimation",
            "startFireworks",
            "stopFireworks",
            "updateBoxMaterial(isOnSlot:true)"
        ])
    }
}
