import Foundation
import Testing

@testable import SortVision

// MARK: - GameManager Star Rating Tests

@Suite("GameManager Star Rating")
@MainActor
struct GameManagerStarRatingTests {

    // MARK: - Star Calculation Edge Cases

    @Test("calculateStars boundary: exactly at 1.5× optimal gets 2 stars")
    func starsBoundaryAt1_5x() {
        // optimal = 10, 1.5× = 15
        #expect(GameManager.calculateStars(moves: 15, optimal: 10) == 2)
    }

    @Test("calculateStars boundary: one above 1.5× optimal gets 1 star")
    func starsOneAbove1_5x() {
        // optimal = 10, 1.5× = 15, so 16 should be 1 star
        #expect(GameManager.calculateStars(moves: 16, optimal: 10) == 1)
    }

    @Test("calculateStars with optimal = 1")
    func starsWithOptimalOne() {
        #expect(GameManager.calculateStars(moves: 1, optimal: 1) == 3)
        // 1.5× of 1 = 1 (Int truncation), so moves=2 exceeds it
        #expect(GameManager.calculateStars(moves: 2, optimal: 1) == 1)
    }

    @Test("calculateStars with negative optimal returns 1 star")
    func starsWithNegativeOptimal() {
        #expect(GameManager.calculateStars(moves: 1, optimal: -5) == 1)
    }

    // MARK: - Level Completion with Stars

    @Test("completeLevel records best move count (keeps lowest)")
    func completeLevelKeepsBestMoves() {
        let snapshot = UserDefaultsSnapshot(keys: UserDefaultsSnapshot.gameManagerKeys + [
            ProgressStore.bestMovesKey, ProgressStore.starRatingsKey
        ])
        defer { snapshot.restore() }

        // First completion with 10 moves
        GameManager.shared.completeLevel(number: 1, moves: 10)
        #expect(GameManager.shared.bestMoveCount(for: 1) == 10)

        // Second completion with 5 moves — should update to 5
        GameManager.shared.completeLevel(number: 1, moves: 5)
        #expect(GameManager.shared.bestMoveCount(for: 1) == 5)

        // Third completion with 8 moves — should stay at 5
        GameManager.shared.completeLevel(number: 1, moves: 8)
        #expect(GameManager.shared.bestMoveCount(for: 1) == 5)
    }

    @Test("completeLevel records star rating (keeps highest)")
    func completeLevelKeepsHighestStars() {
        let snapshot = UserDefaultsSnapshot(keys: UserDefaultsSnapshot.gameManagerKeys + [
            ProgressStore.bestMovesKey, ProgressStore.starRatingsKey
        ])
        defer { snapshot.restore() }

        // Star rating depends on optimal moves, which are loaded from bundle
        // We test the behavior of the star tracking (max retention)
        let level1 = GameManager.shared.level(globalNumber: 1)
        #expect(level1 != nil)

        // Complete with many moves (likely 1 star)
        GameManager.shared.completeLevel(number: 1, moves: 100)
        let firstStars = GameManager.shared.starRating(for: 1)
        #expect(firstStars >= 1)

        // Complete again with same moves — stars should not decrease
        GameManager.shared.completeLevel(number: 1, moves: 100)
        #expect(GameManager.shared.starRating(for: 1) >= firstStars)
    }

    @Test("starRating returns 0 for unplayed levels")
    func starRatingUnplayed() {
        #expect(GameManager.shared.starRating(for: 99999) == 0)
    }

    @Test("bestMoveCount returns nil for unplayed levels")
    func bestMoveCountUnplayed() {
        #expect(GameManager.shared.bestMoveCount(for: 99999) == nil)
    }

    // MARK: - Aggregate Stats

    @Test("totalStars and maxStars are non-negative")
    func aggregateStatsNonNegative() {
        #expect(GameManager.shared.totalStars >= 0)
        #expect(GameManager.shared.maxStars >= 0)
    }

    @Test("maxStars equals total levels × 3")
    func maxStarsCalculation() {
        let totalLevels = Stage.allCases.reduce(0) {
            $0 + GameManager.shared.levels(for: $1).count
        }
        #expect(GameManager.shared.maxStars == totalLevels * 3)
    }

    // MARK: - Reset

    @Test("resetAllProgress clears everything")
    func resetClearsAll() {
        let snapshot = UserDefaultsSnapshot(keys: UserDefaultsSnapshot.gameManagerKeys + [
            ProgressStore.bestMovesKey, ProgressStore.starRatingsKey
        ])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 5, moves: 3)
        GameManager.shared.resetAllProgress()

        #expect(GameManager.shared.completedLevel == 0)
        #expect(GameManager.shared.bestMoveCount(for: 5) == nil)
        #expect(GameManager.shared.starRating(for: 5) == 0)
    }
}

// MARK: - WorldData Codable Tests

@Suite("WorldData")
struct WorldDataTests {

    @Test("WorldData decodes from JSON with optimalPushCounts key")
    func worldDataDecoding() throws {
        let json = """
        { "optimalPushCounts": [5, 8, 12, 3] }
        """
        let data = Data(json.utf8)
        let worldData = try JSONDecoder().decode(WorldData.self, from: data)

        #expect(worldData.optimalMoveCounts == [5, 8, 12, 3])
    }

    @Test("WorldData with empty array decodes correctly")
    func worldDataEmptyArray() throws {
        let json = """
        { "optimalPushCounts": [] }
        """
        let data = Data(json.utf8)
        let worldData = try JSONDecoder().decode(WorldData.self, from: data)

        #expect(worldData.optimalMoveCounts.isEmpty)
    }

    @Test("WorldData without required key throws")
    func worldDataMissingKey() {
        let json = """
        { "wrongKey": [1, 2, 3] }
        """
        let data = Data(json.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(WorldData.self, from: data)
        }
    }
}
