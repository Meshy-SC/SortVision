// LevelProgressTests.swift
// Tests for the LevelProgress value type.

import Testing
import Foundation
@testable import Pushbox

@Suite("LevelProgress")
struct LevelProgressTests {

    @Test("Initialization stores values correctly")
    func initialization() {
        let progress = LevelProgress(isCompleted: true, boxPushes: 12, starRating: 2)
        #expect(progress.isCompleted == true)
        #expect(progress.boxPushes == 12)
        #expect(progress.starRating == 2)
    }

    @Test("Star rating is clamped to maximum of 3")
    func starRatingClampedMax() {
        let progress = LevelProgress(isCompleted: true, boxPushes: 5, starRating: 5)
        #expect(progress.starRating == 3)
    }

    @Test("Star rating is clamped to minimum of 0")
    func starRatingClampedMin() {
        let progress = LevelProgress(isCompleted: false, boxPushes: 0, starRating: -2)
        #expect(progress.starRating == 0)
    }

    @Test("Star rating of 0 is valid for incomplete levels")
    func zeroStarRating() {
        let progress = LevelProgress(isCompleted: false, boxPushes: 0, starRating: 0)
        #expect(progress.starRating == 0)
    }

    @Test("Codable round-trip preserves values with custom coding keys")
    func codableRoundTrip() throws {
        let original = LevelProgress(isCompleted: true, boxPushes: 8, starRating: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LevelProgress.self, from: data)
        #expect(decoded == original)
    }

    @Test("JSON uses 'completed' key instead of 'isCompleted'")
    func jsonUsesCompletedKey() throws {
        let progress = LevelProgress(isCompleted: true, boxPushes: 5, starRating: 2)
        let data = try JSONEncoder().encode(progress)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["completed"] as? Bool == true)
        #expect(json?["isCompleted"] == nil)
    }

    @Test("Same values are equal")
    func equality() {
        let a = LevelProgress(isCompleted: true, boxPushes: 10, starRating: 3)
        let b = LevelProgress(isCompleted: true, boxPushes: 10, starRating: 3)
        #expect(a == b)
    }

    @Test("Different values are not equal")
    func inequality() {
        let a = LevelProgress(isCompleted: true, boxPushes: 10, starRating: 3)
        let b = LevelProgress(isCompleted: true, boxPushes: 10, starRating: 2)
        #expect(a != b)
    }

    @Test("Hashable: same values produce equal hashes")
    func hashable() {
        let a = LevelProgress(isCompleted: true, boxPushes: 5, starRating: 1)
        let b = LevelProgress(isCompleted: true, boxPushes: 5, starRating: 1)
        #expect(a.hashValue == b.hashValue)
    }
}
