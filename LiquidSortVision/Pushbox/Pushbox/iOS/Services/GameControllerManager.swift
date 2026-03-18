// GameControllerManager.swift
// Game controller input handling for MFi, Xbox, and PlayStation controllers.

#if os(iOS) || os(macOS) || os(tvOS)
import GameController
import Foundation

// MARK: - GameControllerManager

/// Manages game controller connections and translates D-pad / thumbstick input
/// into directional commands for the game scene.
///
/// Supports:
/// - MFi game controllers
/// - Xbox Wireless Controller
/// - PlayStation DualSense / DualShock
/// - Siri Remote (micro gamepad)
///
/// Button mapping (per Apple HIG – Game Controller Best Practices):
/// - **D-pad / Left thumbstick** → directional movement
/// - **B / Circle** → undo last move
/// - **Y / Triangle** → toggle solution playback
/// - **Left shoulder (L1)** → previous level
/// - **Right shoulder (R1)** → next level
/// - **Menu button** → open level selector
///
/// Usage:
/// ```swift
/// @State private var gameControllerManager = GameControllerManager()
///
/// .onChange(of: gameControllerManager.lastInput) { _, input in ... }
/// .onChange(of: gameControllerManager.lastAction) { _, action in ... }
/// .task { gameControllerManager.start() }
/// .onDisappear { gameControllerManager.stop() }
/// ```
@MainActor
@Observable
final class GameControllerManager {
    
    // MARK: - Types
    
    /// Represents a single directional input event from a game controller.
    struct DirectionalInput: Equatable {
        /// Horizontal movement: -1 = left, +1 = right, 0 = none.
        let column: Int
        /// Vertical movement: -1 = up, +1 = down, 0 = none.
        let row: Int
        /// Unique ID to distinguish repeated same-direction presses.
        let id: UInt64
    }
    
    /// Non-directional controller button actions.
    enum ControllerAction: Equatable {
        /// B / Circle — undo the last move.
        case undo
        /// Y / Triangle — toggle solution playback.
        case toggleSolution
        /// Left shoulder (L1) — navigate to the previous level.
        case previousLevel
        /// Right shoulder (R1) — navigate to the next level.
        case nextLevel
        /// Menu button — open the level selector.
        case menu
    }
    
    /// Wrapper that pairs an action with a unique ID so identical
    /// consecutive actions still trigger `onChange`.
    struct ActionEvent: Equatable {
        let action: ControllerAction
        let id: UInt64
    }
    
    /// A controller connection change for HUD feedback.
    struct ConnectionEvent: Equatable {
        /// The product category or display name of the controller.
        let controllerName: String
        /// `true` when the controller just connected, `false` on disconnect.
        let isConnected: Bool
        /// Unique ID so repeated identical events still trigger `onChange`.
        let id: UInt64
    }
    
    // MARK: - Observable Properties
    
    /// The most recent directional input from a game controller.
    /// Observed by the game scene to trigger player movement.
    var lastInput: DirectionalInput?
    
    /// The most recent non-directional action from a game controller.
    var lastAction: ActionEvent?
    
    /// The most recent controller connection change for HUD feedback.
    var lastConnectionEvent: ConnectionEvent?
    
    /// Whether at least one game controller is currently connected.
    var isControllerConnected: Bool = false
    
    // MARK: - Private Properties
    
    /// Counter for generating unique input / action IDs.
    @ObservationIgnored
    private var eventCounter: UInt64 = 0
    
    /// Stored observer tokens for controller connection notifications.
    @ObservationIgnored
    private var connectObserver: Any?
    
    @ObservationIgnored
    private var disconnectObserver: Any?
    
    // MARK: - Lifecycle
    
    /// Starts listening for game controller connections and configures any
    /// already-connected controllers.
    func start() {
        // Configure any controllers already connected at launch
        let current = GCController.controllers()
        for controller in current {
            configureController(controller)
        }
        isControllerConnected = !current.isEmpty
        
        // Listen for new controller connections
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            // The notification is delivered on .main queue, so we're already on
            // the main thread. Use nonisolated(unsafe) to bridge the non-Sendable
            // GCController into the @MainActor Task without a data-race risk.
            nonisolated(unsafe) let safeController = controller
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.configureController(safeController)
                self.isControllerConnected = true
                self.emitConnectionEvent(
                    name: safeController.vendorName ?? String(localized: "Game Controller"),
                    connected: true
                )
            }
        }
        
        // Listen for controller disconnections
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let name = (notification.object as? GCController)?.vendorName
                ?? String(localized: "Game Controller")
            let safeName = name
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isControllerConnected = !GCController.controllers().isEmpty
                self.emitConnectionEvent(name: safeName, connected: false)
            }
        }
        
        // Start wireless discovery for Bluetooth controllers
        GCController.startWirelessControllerDiscovery()
    }
    
    /// Stops listening for controllers and cleans up observers.
    func stop() {
        GCController.stopWirelessControllerDiscovery()
        if let observer = connectObserver {
            NotificationCenter.default.removeObserver(observer)
            connectObserver = nil
        }
        if let observer = disconnectObserver {
            NotificationCenter.default.removeObserver(observer)
            disconnectObserver = nil
        }
    }
    
    // MARK: - Controller Configuration
    
    /// Configures input handlers for a connected controller.
    private func configureController(_ controller: GCController) {
        if let gamepad = controller.extendedGamepad {
            configureExtendedGamepad(gamepad)
        } else if let gamepad = controller.microGamepad {
            configureMicroGamepad(gamepad)
        }
    }
    
    /// Configures D-pad, left thumbstick, and button handlers for an extended gamepad.
    ///
    /// Button mapping follows Apple HIG – Game Controller Best Practices:
    /// - D-pad / left thumbstick → movement
    /// - B / Circle → undo
    /// - Y / Triangle → solution
    /// - L1 / R1 shoulders → previous / next level
    /// - Menu button → level selector
    private func configureExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        // D-pad directional input
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: 0, row: -1) }
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: 0, row: 1) }
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: -1, row: 0) }
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: 1, row: 0) }
        }
        
        // Left thumbstick mirrors D-pad for alternative control
        gamepad.leftThumbstick.up.pressedChangedHandler = gamepad.dpad.up.pressedChangedHandler
        gamepad.leftThumbstick.down.pressedChangedHandler = gamepad.dpad.down.pressedChangedHandler
        gamepad.leftThumbstick.left.pressedChangedHandler = gamepad.dpad.left.pressedChangedHandler
        gamepad.leftThumbstick.right.pressedChangedHandler = gamepad.dpad.right.pressedChangedHandler
        
        // B button (Xbox) / Circle (PlayStation) → undo
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.undo) }
        }
        
        // Y button (Xbox) / Triangle (PlayStation) → toggle solution
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.toggleSolution) }
        }
        
        // Left shoulder (L1) → previous level
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.previousLevel) }
        }
        
        // Right shoulder (R1) → next level
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.nextLevel) }
        }
        
        // Menu button → open level selector
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.menu) }
        }
    }
    
    /// Configures D-pad handlers for a micro gamepad (e.g. Siri Remote).
    ///
    /// Siri Remote button mapping:
    /// - **D-pad** → directional movement
    /// - **Button A (touchpad click)** → undo last move
    /// - **Button X (Play/Pause)** → toggle solution playback
    /// - **Menu button** → open level selector
    ///
    /// Note: Next/previous level are not mapped here because the Siri Remote
    /// lacks shoulder buttons. Users navigate levels via the on-screen toolbar.
    private func configureMicroGamepad(_ gamepad: GCMicroGamepad) {
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: 0, row: -1) }
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: 0, row: 1) }
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: -1, row: 0) }
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitInput(column: 1, row: 0) }
        }
        
        // Button A (touchpad click on Siri Remote) → undo
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.undo) }
        }
        
        // Button X (Play/Pause on Siri Remote) → toggle solution
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.toggleSolution) }
        }
        
        // Menu button on Siri Remote → open level selector
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor [weak self] in self?.emitAction(.menu) }
        }
    }
    
    // MARK: - Input Emission
    
    /// Publishes a new directional input with a unique ID.
    private func emitInput(column: Int, row: Int) {
        eventCounter += 1
        lastInput = DirectionalInput(column: column, row: row, id: eventCounter)
    }
    
    /// Publishes a new non-directional controller action with a unique ID.
    private func emitAction(_ action: ControllerAction) {
        eventCounter += 1
        lastAction = ActionEvent(action: action, id: eventCounter)
    }
    
    /// Publishes a controller connection / disconnection event for HUD feedback.
    private func emitConnectionEvent(name: String, connected: Bool) {
        eventCounter += 1
        lastConnectionEvent = ConnectionEvent(
            controllerName: name,
            isConnected: connected,
            id: eventCounter
        )
    }
}
#endif
