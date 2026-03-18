// PerformanceTests.swift
// XCTest performance benchmarks for core game operations.

import XCTest
@testable import Pushbox

// MARK: - Performance Tests

final class PerformanceTests: XCTestCase {

    // MARK: - GameBoard Creation

    @MainActor
    func testGameBoardCreationPerformance() {
        // Generate a large 30×30 level with walls, boxes, and slots
        let size = 30
        var lines: [String] = []
        for row in 0..<size {
            var line = ""
            for col in 0..<size {
                if row == 0 || row == size - 1 || col == 0 || col == size - 1 {
                    line += "#"
                } else if row == 1 && col == 1 {
                    line += "@"
                } else if row == 2 && col >= 2 && col <= 5 {
                    line += "$"
                } else if row == 3 && col >= 2 && col <= 5 {
                    line += "."
                } else {
                    line += " "
                }
            }
            lines.append(line)
        }

        measure {
            for _ in 0..<100 {
                let _ = GameBoard(from: lines)
            }
        }
    }

    // MARK: - Movement Performance

    @MainActor
    func testMovementPerformance() {
        let level = [
            "##########",
            "#@       #",
            "# $    . #",
            "#        #",
            "#        #",
            "#        #",
            "#        #",
            "#        #",
            "#        #",
            "##########"
        ]

        measure {
            let board = GameBoard(from: level)
            // Perform many moves: walk right, then undo, repeat
            for _ in 0..<500 {
                board.movePlayer(columnDelta: 1, rowDelta: 0)
                board.undoMove()
            }
        }
    }

    // MARK: - Undo Chain Performance

    @MainActor
    func testUndoChainPerformance() {
        let level = [
            "##########",
            "#@       #",
            "#      $.#",
            "#        #",
            "#        #",
            "#        #",
            "#        #",
            "#        #",
            "#        #",
            "##########"
        ]

        measure {
            let board = GameBoard(from: level)
            // Build up a long move history
            for _ in 0..<200 {
                board.movePlayer(columnDelta: 1, rowDelta: 0)
            }
            // Undo everything
            for _ in 0..<200 {
                board.undoMove()
            }
        }
    }

    // MARK: - Progress Service Batch Operations

    @MainActor
    func testProgressServiceBatchCompletionPerformance() {
        let container = ModelContainerFactory.makePreviewContainer()
        let service = ProgressService(modelContext: container.mainContext)
        let world = TestHelpers.makeTestWorld(
            optimalPushCounts: Array(repeating: 10, count: 50)
        )

        measure {
            // Complete 50 levels
            for i in 0..<50 {
                service.currentLevelPushes = 10
                service.completeLevel(for: world, levelIndex: i)
            }
            service.resetAllProgress()
        }
    }
}
