// LevelParsingTests.swift
// Tests for ASCII level parsing logic mirroring GameSceneView+LevelBuilder.swift.

import Testing
import Foundation
@testable import Pushbox

// MARK: - Level Parsing Tests

@MainActor
@Suite("Level Parsing Tests")
struct LevelParsingTests {

    // MARK: - Character Mapping

    @Test("Wall character '#' creates wall cell")
    func wallCharacter() {
        let board = GameBoard(from: ["#@$."])
        #expect(board.cell(at: GridPosition(row: 0, column: 0)) == .wall)
    }

    @Test("Player character '@' creates player cell and sets position")
    func playerCharacter() {
        let board = GameBoard(from: ["#@$."])
        #expect(board.cell(at: GridPosition(row: 0, column: 1)) == .player)
        #expect(board.playerPosition == GridPosition(row: 0, column: 1))
    }

    @Test("Player-on-slot '+' creates player on slot position")
    func playerOnSlotCharacter() {
        let board = GameBoard(from: ["+$."])
        #expect(board.cell(at: GridPosition(row: 0, column: 0)) == .player)
        #expect(board.playerPosition == GridPosition(row: 0, column: 0))
        #expect(board.slotPositions.contains(GridPosition(row: 0, column: 0)))
    }

    @Test("Slot character '.' creates slot cell and tracks position")
    func slotCharacter() {
        let board = GameBoard(from: ["@$."])
        let slotPos = GridPosition(row: 0, column: 2)
        #expect(board.cell(at: slotPos) == .slot)
        #expect(board.slotPositions.contains(slotPos))
    }

    @Test("Box character '$' creates box cell and increments count")
    func boxCharacter() {
        let board = GameBoard(from: ["@$."])
        #expect(board.cell(at: GridPosition(row: 0, column: 1)) == .box)
        #expect(board.totalBoxCount == 1)
        #expect(board.arrivedBoxCount == 0)
    }

    @Test("Box-on-slot '*' creates boxOnSlot, increments total and arrived count")
    func boxOnSlotCharacter() {
        let board = GameBoard(from: ["@*"])
        #expect(board.cell(at: GridPosition(row: 0, column: 1)) == .boxOnSlot)
        #expect(board.totalBoxCount == 1)
        #expect(board.arrivedBoxCount == 1)
        #expect(board.slotPositions.contains(GridPosition(row: 0, column: 1)))
    }

    @Test("Space character creates empty cell")
    func spaceCharacter() {
        let board = GameBoard(from: ["@ $."])
        #expect(board.cell(at: GridPosition(row: 0, column: 1)) == .empty)
    }

    @Test("Unknown characters create empty cells")
    func unknownCharacter() {
        let board = GameBoard(from: ["@X$."])
        #expect(board.cell(at: GridPosition(row: 0, column: 1)) == .empty)
    }

    // MARK: - Grid Dimensions

    @Test("Grid dimensions match input lines")
    func gridDimensions() {
        let lines = [
            "#####",
            "#@$.#",
            "#####"
        ]
        let board = GameBoard(from: lines)
        #expect(board.grid.count == 3)
        #expect(board.grid[0].count == 5)
        #expect(board.grid[1].count == 5)
        #expect(board.grid[2].count == 5)
    }

    @Test("Ragged rows are padded with empty cells")
    func raggedRows() {
        let lines = [
            "###",     // 3 chars
            "#@$.",    // 4 chars
            "###"      // 3 chars
        ]
        let board = GameBoard(from: lines)
        // Max columns = 4, so all rows have 4 cells
        #expect(board.grid[0].count == 4)
        #expect(board.grid[2].count == 4)
        // Padded cell should be empty
        #expect(board.cell(at: GridPosition(row: 0, column: 3)) == .empty)
    }

    @Test("Empty level creates empty grid")
    func emptyLevel() {
        let board = GameBoard(from: [])
        #expect(board.grid.isEmpty)
        #expect(board.playerPosition == nil)
        #expect(board.totalBoxCount == 0)
    }

    // MARK: - Counting

    @Test("Multiple boxes and slots are counted correctly")
    func multipleBoxesAndSlots() {
        let lines = [
            "######",
            "#@$$..#",
            "######"
        ]
        let board = GameBoard(from: lines)
        #expect(board.totalBoxCount == 2)
        #expect(board.arrivedBoxCount == 0)
        #expect(board.slotPositions.count == 2)
    }

    @Test("Mixed arrived and unarrived boxes counted correctly")
    func mixedBoxCounting() {
        let lines = [
            "######",
            "#@*$.#",
            "######"
        ]
        let board = GameBoard(from: lines)
        #expect(board.totalBoxCount == 2)
        #expect(board.arrivedBoxCount == 1)
        #expect(board.slotPositions.count == 2) // * contributes a slot, . is another
    }

    // MARK: - Complex Level

    @Test("Full Sokoban level parses correctly")
    func complexLevel() {
        let lines = [
            "  ####",
            "###  #",
            "# $. #",
            "# .$ #",
            "#@ ###",
            "####"
        ]
        let board = GameBoard(from: lines)
        #expect(board.playerPosition == GridPosition(row: 4, column: 1))
        #expect(board.totalBoxCount == 2)
        #expect(board.arrivedBoxCount == 0)
        #expect(board.slotPositions.count == 2)
        #expect(board.isLevelCompleted == false)
        // Verify some cells
        #expect(board.cell(at: GridPosition(row: 0, column: 0)) == .empty) // space
        #expect(board.cell(at: GridPosition(row: 0, column: 2)) == .wall)
        #expect(board.cell(at: GridPosition(row: 2, column: 2)) == .box)
        #expect(board.cell(at: GridPosition(row: 2, column: 3)) == .slot)
    }

    // MARK: - Bounds Checking

    @Test("isWithinBounds returns true for valid positions")
    func withinBounds() {
        let board = GameBoard(from: ["###", "#@$", "###"])
        #expect(board.isWithinBounds(GridPosition(row: 0, column: 0)) == true)
        #expect(board.isWithinBounds(GridPosition(row: 2, column: 2)) == true)
    }

    @Test("isWithinBounds returns false for out-of-range positions")
    func outOfBounds() {
        let board = GameBoard(from: ["###", "#@$", "###"])
        #expect(board.isWithinBounds(GridPosition(row: -1, column: 0)) == false)
        #expect(board.isWithinBounds(GridPosition(row: 3, column: 0)) == false)
        #expect(board.isWithinBounds(GridPosition(row: 0, column: 3)) == false)
        #expect(board.isWithinBounds(GridPosition(row: 0, column: -1)) == false)
    }
}
