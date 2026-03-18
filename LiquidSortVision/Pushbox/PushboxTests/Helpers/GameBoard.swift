// GameBoard.swift
// Pure-logic Sokoban board for testing movement rules without RealityKit entities.
// Faithfully mirrors the grid-state logic from GameSceneView+Movement.swift.

import Foundation
@testable import Pushbox

// MARK: - GameBoard

/// A standalone Sokoban board that replicates the movement logic from
/// `GameSceneView+Movement.swift` without any RealityKit dependencies.
///
/// Every grid mutation, undo step, push-count adjustment, and level-completion
/// check follows the same algorithm as the production code so that unit tests
/// on this class validate the core game rules.
@MainActor
final class GameBoard {

    // MARK: - Cell Type

    /// Represents what occupies a single grid cell (mirrors `CellContent` without Entity).
    enum Cell: Equatable, CustomStringConvertible {
        case empty
        case wall
        case box
        case boxOnSlot
        case player
        case slot

        var isWalkable: Bool {
            switch self {
            case .empty, .slot: true
            default: false
            }
        }

        var isBox: Bool {
            switch self {
            case .box, .boxOnSlot: true
            default: false
            }
        }

        var isBoxOnSlot: Bool {
            if case .boxOnSlot = self { return true }
            return false
        }

        var isWall: Bool {
            if case .wall = self { return true }
            return false
        }

        var description: String {
            switch self {
            case .empty:     " "
            case .wall:      "#"
            case .box:       "$"
            case .boxOnSlot: "*"
            case .player:    "@"
            case .slot:      "."
            }
        }
    }

    // MARK: - Move Record

    /// Records a single move for undo (mirrors `MoveRecord` without Entity).
    struct Move {
        let playerFrom: GridPosition
        let playerTo: GridPosition
        let didPushBox: Bool
        let boxFrom: GridPosition?
        let boxTo: GridPosition?
        let wasBoxOnSlot: Bool
    }

    // MARK: - Move Result

    enum MoveResult: Equatable {
        case moved
        case pushed
        case blocked
    }

    // MARK: - Properties

    var grid: [[Cell]]
    var playerPosition: GridPosition?
    var slotPositions: Set<GridPosition>
    var totalBoxCount: Int = 0
    var arrivedBoxCount: Int = 0
    var moveHistory: [Move] = []
    var isLevelCompleted: Bool = false
    var pushCount: Int = 0

    // MARK: - Initialization

    /// Creates a board from ASCII level lines.
    /// Character mapping matches `GameSceneView+LevelBuilder.swift`:
    /// `#` wall, `@` player, `+` player on slot, `.` slot, `$` box, `*` box on slot.
    init(from lines: [String]) {
        let maxColumns = lines.map(\.count).max() ?? 0
        grid = Array(repeating: Array(repeating: Cell.empty, count: maxColumns),
                     count: lines.count)
        slotPositions = []

        for (row, line) in lines.enumerated() {
            for (col, char) in line.enumerated() {
                let pos = GridPosition(row: row, column: col)
                switch char {
                case "#":
                    grid[row][col] = .wall
                case "@":
                    grid[row][col] = .player
                    playerPosition = pos
                case "+":
                    grid[row][col] = .player
                    playerPosition = pos
                    slotPositions.insert(pos)
                case ".":
                    grid[row][col] = .slot
                    slotPositions.insert(pos)
                case "$":
                    grid[row][col] = .box
                    totalBoxCount += 1
                case "*":
                    grid[row][col] = .boxOnSlot
                    slotPositions.insert(pos)
                    totalBoxCount += 1
                    arrivedBoxCount += 1
                default:
                    break
                }
            }
        }
    }

    // MARK: - Bounds Check

    /// Mirrors `GameSceneView.isWithinBounds(_:)`.
    func isWithinBounds(_ position: GridPosition) -> Bool {
        position.row >= 0 && position.row < grid.count &&
        position.column >= 0 && position.column < grid[position.row].count
    }

    /// Convenience accessor for a cell at a given position.
    func cell(at position: GridPosition) -> Cell {
        guard isWithinBounds(position) else { return .empty }
        return grid[position.row][position.column]
    }

    // MARK: - Movement

    /// Attempts to move the player in the given direction.
    /// Mirrors the logic in `GameSceneView.movePlayer(columnDelta:rowDelta:)`.
    @discardableResult
    func movePlayer(columnDelta: Int, rowDelta: Int) -> MoveResult {
        guard !isLevelCompleted, let fromPosition = playerPosition else { return .blocked }

        let toPosition = GridPosition(row: fromPosition.row + rowDelta,
                                      column: fromPosition.column + columnDelta)
        guard isWithinBounds(toPosition) else { return .blocked }

        var validMove = false
        var didPushBox = false
        var wasBoxOnSlot = false
        var boxFrom: GridPosition?
        var boxTo: GridPosition?

        switch grid[toPosition.row][toPosition.column] {
        case .wall:
            break

        case .box, .boxOnSlot:
            let boxDestination = GridPosition(row: toPosition.row + rowDelta,
                                              column: toPosition.column + columnDelta)
            guard isWithinBounds(boxDestination),
                  grid[boxDestination.row][boxDestination.column].isWalkable else { break }

            validMove = true
            didPushBox = true
            boxFrom = toPosition
            boxTo = boxDestination
            wasBoxOnSlot = grid[toPosition.row][toPosition.column].isBoxOnSlot

            // Update box destination
            if slotPositions.contains(boxDestination) {
                grid[boxDestination.row][boxDestination.column] = .boxOnSlot
                arrivedBoxCount += 1
            } else {
                grid[boxDestination.row][boxDestination.column] = .box
            }

            // Update box origin
            if slotPositions.contains(toPosition) {
                grid[toPosition.row][toPosition.column] = .slot
                if wasBoxOnSlot { arrivedBoxCount -= 1 }
            } else {
                grid[toPosition.row][toPosition.column] = .empty
                if wasBoxOnSlot { arrivedBoxCount -= 1 }
            }

        case .empty, .slot:
            validMove = true

        case .player:
            break
        }

        guard validMove else { return .blocked }

        // Record move
        let record = Move(
            playerFrom: fromPosition,
            playerTo: toPosition,
            didPushBox: didPushBox,
            boxFrom: boxFrom,
            boxTo: boxTo,
            wasBoxOnSlot: wasBoxOnSlot
        )
        moveHistory.append(record)

        // Update push count
        if didPushBox { pushCount += 1 }

        // Move player on the grid
        if slotPositions.contains(fromPosition) {
            grid[fromPosition.row][fromPosition.column] = .slot
        } else {
            grid[fromPosition.row][fromPosition.column] = .empty
        }
        grid[toPosition.row][toPosition.column] = .player
        playerPosition = toPosition

        // Check completion
        checkLevelCompleted()

        return didPushBox ? .pushed : .moved
    }

    // MARK: - Undo

    /// Undoes the last move, restoring all grid state.
    /// Mirrors `GameSceneView.undoMove()`.
    @discardableResult
    func undoMove() -> Bool {
        guard !isLevelCompleted, let last = moveHistory.popLast() else { return false }

        if last.didPushBox { pushCount -= 1 }

        // Restore player's destination cell
        if slotPositions.contains(last.playerTo) {
            grid[last.playerTo.row][last.playerTo.column] = .slot
        } else {
            grid[last.playerTo.row][last.playerTo.column] = .empty
        }
        grid[last.playerFrom.row][last.playerFrom.column] = .player
        playerPosition = last.playerFrom

        // Restore box if one was pushed
        if last.didPushBox,
           let boxFrom = last.boxFrom,
           let boxTo = last.boxTo {

            // Remove box from its pushed-to position
            if slotPositions.contains(boxTo) {
                grid[boxTo.row][boxTo.column] = .slot
                arrivedBoxCount -= 1
            } else {
                grid[boxTo.row][boxTo.column] = .empty
            }

            // Restore box to its original position
            if last.wasBoxOnSlot {
                grid[boxFrom.row][boxFrom.column] = .boxOnSlot
                arrivedBoxCount += 1
            } else {
                grid[boxFrom.row][boxFrom.column] = .box
            }
        }

        return true
    }

    // MARK: - Level Completion

    /// Mirrors `GameSceneView.checkLevelCompleted()`.
    private func checkLevelCompleted() {
        guard arrivedBoxCount == totalBoxCount, totalBoxCount > 0 else { return }
        isLevelCompleted = true
    }
}
