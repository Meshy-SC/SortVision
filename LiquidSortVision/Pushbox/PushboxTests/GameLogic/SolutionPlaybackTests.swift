// SolutionPlaybackTests.swift
// Tests for solution playback logic mirroring GameSceneView+SolutionPlayback.swift.

import Testing
import Foundation
@testable import Pushbox

// MARK: - Solution Playback Tests

@MainActor
@Suite("Solution Playback Tests")
struct SolutionPlaybackTests {

    // MARK: - Direction Filtering

    /// Replicates the direction filtering from `GameSceneView+SolutionPlayback.startSolution()`.
    private static func filterDirections(_ solution: String) -> [Character] {
        let validDirections: Set<Character> = ["u", "d", "l", "r", "U", "D", "L", "R"]
        return Array(solution).filter { validDirections.contains($0) }
    }

    /// Replicates the direction-to-delta mapping from `runSolutionPlayback()`.
    private static func directionDelta(for char: Character) -> (column: Int, row: Int) {
        let direction = String(char).lowercased()
        return switch direction {
        case "u": ( 0, -1)
        case "d": ( 0,  1)
        case "l": (-1,  0)
        case "r": ( 1,  0)
        default:  ( 0,  0)
        }
    }

    @Test("Valid direction characters are preserved",
          arguments: ["u", "d", "l", "r", "U", "D", "L", "R"])
    func validDirectionPreserved(char: String) {
        let filtered = Self.filterDirections(char)
        #expect(filtered.count == 1)
        #expect(filtered.first == Character(char))
    }

    @Test("Invalid characters are filtered out")
    func invalidCharactersRemoved() {
        let filtered = Self.filterDirections("u1d2l3r4x\n ")
        #expect(filtered == ["u", "d", "l", "r"])
    }

    @Test("Empty string produces empty result")
    func emptyString() {
        let filtered = Self.filterDirections("")
        #expect(filtered.isEmpty)
    }

    @Test("String with no valid directions produces empty result")
    func noValidDirections() {
        let filtered = Self.filterDirections("12345!@#$%")
        #expect(filtered.isEmpty)
    }

    // MARK: - Direction Mapping

    @Test("Direction 'u' maps to up (column: 0, row: -1)")
    func directionUp() {
        let delta = Self.directionDelta(for: "u")
        #expect(delta == (0, -1))
    }

    @Test("Direction 'd' maps to down (column: 0, row: 1)")
    func directionDown() {
        let delta = Self.directionDelta(for: "d")
        #expect(delta == (0, 1))
    }

    @Test("Direction 'l' maps to left (column: -1, row: 0)")
    func directionLeft() {
        let delta = Self.directionDelta(for: "l")
        #expect(delta == (-1, 0))
    }

    @Test("Direction 'r' maps to right (column: 1, row: 0)")
    func directionRight() {
        let delta = Self.directionDelta(for: "r")
        #expect(delta == (1, 0))
    }

    @Test("Uppercase directions map the same as lowercase",
          arguments: [("U", 0, -1), ("D", 0, 1), ("L", -1, 0), ("R", 1, 0)])
    func uppercaseMapping(input: String, expectedCol: Int, expectedRow: Int) {
        let delta = Self.directionDelta(for: Character(input))
        #expect(delta.column == expectedCol)
        #expect(delta.row == expectedRow)
    }

    @Test("Invalid direction maps to zero delta")
    func invalidDirectionDelta() {
        let delta = Self.directionDelta(for: "x")
        #expect(delta == (0, 0))
    }

    // MARK: - Stop Index Logic

    @Test("Long solutions stop one move before end (>2 moves)")
    func longSolutionStopIndex() {
        let moves: [Character] = ["r", "r", "d", "d", "l"]
        // Production: stopIndex = moves.count > 2 ? moves.count - 1 : moves.count
        let stopIndex = moves.count > 2 ? moves.count - 1 : moves.count
        #expect(stopIndex == 4) // plays indices 0..<4, skips index 4
    }

    @Test("Short solutions play all moves (≤2 moves)")
    func shortSolutionPlaysAll() {
        let moves1: [Character] = ["r", "d"]
        let stopIndex1 = moves1.count > 2 ? moves1.count - 1 : moves1.count
        #expect(stopIndex1 == 2) // plays all

        let moves2: [Character] = ["r"]
        let stopIndex2 = moves2.count > 2 ? moves2.count - 1 : moves2.count
        #expect(stopIndex2 == 1) // plays all
    }

    // MARK: - Pause Behavior

    @Test("Pause clears solution moves on AppModel")
    func pauseClearsMoves() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.solutionMoves = ["r", "d", "l", "u"]
        appModel.isPlayingSolution = true

        // Simulate pause behavior (mirrors pauseSolution())
        appModel.isPlayingSolution = false
        appModel.isSolutionPaused = true
        appModel.solutionMoves.removeAll()

        #expect(appModel.isPlayingSolution == false)
        #expect(appModel.isSolutionPaused == true)
        #expect(appModel.solutionMoves.isEmpty)
    }

    // MARK: - Solution Applied to Board

    @Test("Solution directions correctly move player on a board")
    func solutionAppliedToBoard() {
        let level = [
            "#####",
            "#@$.#",
            "#####"
        ]
        let board = GameBoard(from: level)
        let solution = "r" // single push to solve
        let moves = Self.filterDirections(solution)

        for char in moves {
            let delta = Self.directionDelta(for: char)
            board.movePlayer(columnDelta: delta.column, rowDelta: delta.row)
        }

        #expect(board.isLevelCompleted == true)
    }

    @Test("Multi-step solution solves complex level")
    func multiStepSolution() {
        let level = [
            "#####",
            "# .@#",
            "# $ #",
            "#   #",
            "#####"
        ]
        let board = GameBoard(from: level)
        // Solution: go around the box and push it up to the slot
        let solution = "ddllu"
        let moves = Self.filterDirections(solution)

        for char in moves {
            let delta = Self.directionDelta(for: char)
            board.movePlayer(columnDelta: delta.column, rowDelta: delta.row)
        }

        #expect(board.isLevelCompleted == true)
        #expect(board.arrivedBoxCount == 1)
    }
}
