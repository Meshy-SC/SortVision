import XCTest

/// UI tests for gameplay interactions.
///
/// Tests the SpriteKit game scene through the SwiftUI wrapper,
/// validating restart functionality and HUD interactions.
final class GameplayUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Helper: Navigate from main menu to Level 1 of Easy mode.
    private func navigateToEasyLevel1() {
        app.buttons["PLAY"].tap()

        let easyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Easy'")
        ).firstMatch
        guard easyButton.waitForExistence(timeout: 3) else {
            XCTFail("Could not find Easy button")
            return
        }
        easyButton.tap()

        let level1 = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Level 1'")
        ).firstMatch
        guard level1.waitForExistence(timeout: 3) else {
            XCTFail("Could not find Level 1 tile")
            return
        }
        level1.tap()
    }

    // MARK: - Gameplay HUD

    func testGameplayHUDElementsPresent() throws {
        navigateToEasyLevel1()

        let levelLabel = app.staticTexts["Level 1"]
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 5),
                      "Level number should be displayed in HUD")

        let homeButton = app.buttons["Home"]
        XCTAssertTrue(homeButton.exists, "Home button should be in HUD")

        let restartButton = app.buttons["Restart level"]
        XCTAssertTrue(restartButton.exists, "Restart button should be in HUD")
    }

    // MARK: - Restart

    func testRestartButtonReloadsLevel() throws {
        navigateToEasyLevel1()

        let restartButton = app.buttons["Restart level"]
        XCTAssertTrue(restartButton.waitForExistence(timeout: 5))
        restartButton.tap()

        // After restart, the level label should still be visible
        let levelLabel = app.staticTexts["Level 1"]
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 3),
                      "Level should remain the same after restart")
    }

    // MARK: - Keyboard Shortcuts (macOS)

    #if os(macOS)
    func testCommandRRestartsLevel() throws {
        navigateToEasyLevel1()

        let levelLabel = app.staticTexts["Level 1"]
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 5))

        // Press Cmd+R
        app.typeKey("r", modifierFlags: .command)

        // Level should still be shown
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 3))
    }

    func testCommandHGoesHome() throws {
        navigateToEasyLevel1()

        // Press Cmd+H (note: may conflict with system shortcut)
        app.typeKey("h", modifierFlags: .command)

        let playButton = app.buttons["PLAY"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
    }
    #endif

    // MARK: - Level Completion Overlay (manual verification)

    func testLevelCompletionOverlayMainMenuButton() throws {
        // This test validates the overlay structure if it appears.
        // Full automation of solving a puzzle is complex and better suited
        // for integration tests with direct GameScene manipulation.
        // For now, we verify the gameplay loads without crashes.
        navigateToEasyLevel1()

        let levelLabel = app.staticTexts["Level 1"]
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 5),
                      "Gameplay should load without crashes")
    }

    // MARK: - Performance

    func testNavigationPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            app.buttons["PLAY"].tap()

            let easyButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Easy'")
            ).firstMatch
            guard easyButton.waitForExistence(timeout: 5) else { return }
            easyButton.tap()

            let level1 = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'Level 1'")
            ).firstMatch
            guard level1.waitForExistence(timeout: 5) else { return }

            // Navigate back
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
                let header = app.staticTexts["Select Difficulty"]
                _ = header.waitForExistence(timeout: 3)
            }

            // Navigate back to main menu using system back or re-launch
            app.terminate()
            app.launch()
        }
    }
}
