// GameControllerManagerTests.swift
// Tests for GameControllerManager DirectionalInput, ControllerAction, ConnectionEvent, and lifecycle.

#if os(iOS) || os(macOS)
import Testing
import Foundation
import GameController
@testable import Pushbox

// MARK: - GameControllerManager Tests

@MainActor
@Suite("GameControllerManager Tests")
struct GameControllerManagerTests {

    // MARK: - DirectionalInput

    @Test("DirectionalInput stores column and row values")
    func inputStoresValues() {
        let input = GameControllerManager.DirectionalInput(column: -1, row: 0, id: 1)
        #expect(input.column == -1)
        #expect(input.row == 0)
        #expect(input.id == 1)
    }

    @Test("DirectionalInput equality requires matching column, row, and id")
    func inputEquality() {
        let a = GameControllerManager.DirectionalInput(column: 1, row: 0, id: 1)
        let b = GameControllerManager.DirectionalInput(column: 1, row: 0, id: 1)
        let c = GameControllerManager.DirectionalInput(column: 1, row: 0, id: 2)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("All four cardinal directions represented",
          arguments: [(1, 0, "right"), (-1, 0, "left"), (0, -1, "up"), (0, 1, "down")])
    func cardinalDirections(column: Int, row: Int, label: String) {
        let input = GameControllerManager.DirectionalInput(column: column, row: row, id: 1)
        #expect(input.column == column)
        #expect(input.row == row)
    }

    // MARK: - ControllerAction

    @Test("ControllerAction cases are distinct")
    func actionCasesDistinct() {
        let actions: [GameControllerManager.ControllerAction] = [
            .undo, .toggleSolution, .previousLevel, .nextLevel, .menu
        ]
        for (i, a) in actions.enumerated() {
            for (j, b) in actions.enumerated() where i != j {
                #expect(a != b, "Expected \(a) != \(b)")
            }
        }
    }

    @Test("ActionEvent equality requires matching action and id")
    func actionEventEquality() {
        let a = GameControllerManager.ActionEvent(action: .undo, id: 1)
        let b = GameControllerManager.ActionEvent(action: .undo, id: 1)
        let c = GameControllerManager.ActionEvent(action: .undo, id: 2)
        let d = GameControllerManager.ActionEvent(action: .nextLevel, id: 1)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    // MARK: - ConnectionEvent

    @Test("ConnectionEvent stores controller name and connection state")
    func connectionEventStoresValues() {
        let event = GameControllerManager.ConnectionEvent(
            controllerName: "Xbox Wireless Controller",
            isConnected: true,
            id: 1
        )
        #expect(event.controllerName == "Xbox Wireless Controller")
        #expect(event.isConnected == true)
        #expect(event.id == 1)
    }

    @Test("ConnectionEvent equality requires matching all fields")
    func connectionEventEquality() {
        let a = GameControllerManager.ConnectionEvent(controllerName: "Xbox", isConnected: true, id: 1)
        let b = GameControllerManager.ConnectionEvent(controllerName: "Xbox", isConnected: true, id: 1)
        let c = GameControllerManager.ConnectionEvent(controllerName: "Xbox", isConnected: false, id: 1)
        let d = GameControllerManager.ConnectionEvent(controllerName: "Xbox", isConnected: true, id: 2)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    // MARK: - Manager State

    @Test("Initial lastInput is nil")
    func initialLastInput() {
        let manager = GameControllerManager()
        #expect(manager.lastInput == nil)
    }

    @Test("Initial lastAction is nil")
    func initialLastAction() {
        let manager = GameControllerManager()
        #expect(manager.lastAction == nil)
    }

    @Test("Initial lastConnectionEvent is nil")
    func initialConnectionEvent() {
        let manager = GameControllerManager()
        #expect(manager.lastConnectionEvent == nil)
    }

    @Test("Initial isControllerConnected is false")
    func initialConnectionState() {
        let manager = GameControllerManager()
        #expect(manager.isControllerConnected == false)
    }

    // MARK: - Lifecycle

    @Test("Start and stop lifecycle do not crash")
    func startStopLifecycle() {
        let manager = GameControllerManager()
        manager.start()
        manager.stop()
        // No crash = pass
    }

    @Test("Stop without start does not crash")
    func stopWithoutStart() {
        let manager = GameControllerManager()
        manager.stop()
    }
}
#endif
