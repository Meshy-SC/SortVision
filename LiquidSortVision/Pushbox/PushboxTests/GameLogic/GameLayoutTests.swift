// GameLayoutTests.swift
// Tests for GameLayout constants.

import Testing
@testable import Pushbox

@Suite("GameLayout")
struct GameLayoutTests {

    @Test("Cell size is a positive value")
    func cellSizePositive() {
        #expect(GameLayout.cellSize > 0)
    }

    @Test("Animation duration is a positive value")
    func animationDurationPositive() {
        #expect(GameLayout.animationDuration > 0)
    }

    @Test("Control panel delay is longer than animation duration")
    func controlPanelDelayLongerThanAnimation() {
        #expect(GameLayout.controlPanelDelay > GameLayout.animationDuration)
    }

    @Test("Level reveal delay is shorter than animation duration")
    func levelRevealDelayShorterThanAnimation() {
        #expect(GameLayout.levelRevealDelay <= GameLayout.animationDuration)
    }

    @Test("Audio delays are positive")
    func audioDelaysPositive() {
        #expect(GameLayout.arrivalAudioDelay > 0)
        #expect(GameLayout.postLevelLoadAudioDelay > 0)
    }
}
