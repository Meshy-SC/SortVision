// GameCenterServiceTests.swift
// Tests for GameCenterService state and configuration.

import Testing
import Foundation
import GameKit
@testable import Pushbox

// MARK: - GameCenterService Tests

@MainActor
@Suite("GameCenterService Tests")
struct GameCenterServiceTests {

    @Test("Global score leaderboard ID is correct")
    func leaderboardID() {
        #expect(GameCenterService.globalScoreLeaderboardID == "fr.meshy.pushbox.globalscore")
    }

    @Test("isAuthenticated defaults to false before authentication completes")
    func defaultAuthState() {
        let service = GameCenterService()
        // Authentication is async — synchronous check should show false
        #expect(service.isAuthenticated == false)
    }

    @Test("submitScore is a no-op when not authenticated")
    func submitScoreNotAuthenticated() {
        let service = GameCenterService()
        #expect(service.isAuthenticated == false)
        // Should not crash or throw
        service.submitScore(100)
    }

    @Test("Service can be instantiated")
    func serviceInit() {
        let service = GameCenterService()
        // Successfully created without crash
        _ = service
    }
}
