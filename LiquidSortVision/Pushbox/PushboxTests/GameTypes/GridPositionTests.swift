// GridPositionTests.swift
// Tests for the GridPosition value type.

import Testing
import Foundation
@testable import Pushbox

@Suite("GridPosition")
struct GridPositionTests {

    @Test("Initialization stores row and column")
    func initialization() {
        let pos = GridPosition(row: 3, column: 7)
        #expect(pos.row == 3)
        #expect(pos.column == 7)
    }

    @Test("Positions with same values are equal")
    func equality() {
        let a = GridPosition(row: 2, column: 5)
        let b = GridPosition(row: 2, column: 5)
        #expect(a == b)
    }

    @Test("Positions with different values are not equal")
    func inequality() {
        let a = GridPosition(row: 1, column: 2)
        let b = GridPosition(row: 2, column: 1)
        #expect(a != b)
    }

    @Test("Same positions produce equal hash values for Set usage")
    func hashableForSets() {
        let positions: Set<GridPosition> = [
            GridPosition(row: 0, column: 0),
            GridPosition(row: 0, column: 0),
            GridPosition(row: 1, column: 1)
        ]
        #expect(positions.count == 2)
    }

    @Test("Codable round-trip preserves values")
    func codableRoundTrip() throws {
        let original = GridPosition(row: 4, column: 8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GridPosition.self, from: data)
        #expect(decoded == original)
    }

    @Test("Negative coordinates are valid grid positions")
    func negativeCoordinates() {
        let pos = GridPosition(row: -1, column: -3)
        #expect(pos.row == -1)
        #expect(pos.column == -3)
    }

    @Test("Zero coordinates create valid position")
    func zeroCoordinates() {
        let pos = GridPosition(row: 0, column: 0)
        #expect(pos.row == 0)
        #expect(pos.column == 0)
    }
}
