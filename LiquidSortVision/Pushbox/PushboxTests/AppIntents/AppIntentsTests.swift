// AppIntentsTests.swift
// Tests for PushBox App Intents and Shortcuts.

import Testing
import Foundation
import AppIntents
@testable import Pushbox

// MARK: - AppIntents Tests

@MainActor
@Suite("AppIntents Tests")
struct AppIntentsTests {

    @Test("ContinuePuzzleIntent is configured to open the app")
    func continueOpensApp() {
        #expect(ContinuePuzzleIntent.openAppWhenRun == true)
    }

    @Test("ShowProgressIntent is configured to open the app")
    func showProgressOpensApp() {
        #expect(ShowProgressIntent.openAppWhenRun == true)
    }

    @Test("ContinuePuzzleIntent can be instantiated")
    func continueIntentInit() {
        let intent = ContinuePuzzleIntent()
        _ = intent
    }

    @Test("ShowProgressIntent can be instantiated")
    func showProgressIntentInit() {
        let intent = ShowProgressIntent()
        _ = intent
    }

    @Test("PushBoxShortcuts provides non-empty shortcuts array")
    func shortcutsProvided() {
        let shortcuts = PushBoxShortcuts.appShortcuts
        #expect(!shortcuts.isEmpty)
    }

    @Test("ContinuePuzzleIntent perform returns dialog")
    func continueIntentPerform() async throws {
        let intent = ContinuePuzzleIntent()
        let result = try await intent.perform()
        // Successfully returns without error
        _ = result
    }
}
