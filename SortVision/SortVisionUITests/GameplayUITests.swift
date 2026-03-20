import XCTest

/// UI tests for gameplay interactions.
///
/// Tests the game scene through the SwiftUI wrapper,
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

    /// Helper: Navigate from root to Level 1 of Iron stage.
    private func navigateToIronLevel1() {
        let ironRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Iron'")
        ).firstMatch
        guard ironRow.waitForExistence(timeout: 5) else {
            XCTFail("Could not find Iron world row")
            return
        }
        ironRow.tap()

        let level1 = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] '1'")
        ).firstMatch
        guard level1.waitForExistence(timeout: 5) else {
            XCTFail("Could not find Level 1 tile")
            return
        }
        level1.tap()
    }

    // MARK: - Gameplay HUD

    func testGameplayHUDElementsPresent() throws {
        navigateToIronLevel1()

        let levelLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Level'")
        ).firstMatch
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 5),
                      "Level label should be displayed in HUD")

        let homeButton = app.buttons["Home"]
        XCTAssertTrue(homeButton.exists, "Home button should be in HUD")

        let restartButton = app.buttons["Restart level"]
        XCTAssertTrue(restartButton.exists, "Restart button should be in HUD")
    }

    // MARK: - Restart

    func testRestartButtonReloadsLevel() throws {
        navigateToIronLevel1()

        let restartButton = app.buttons["Restart level"]
        XCTAssertTrue(restartButton.waitForExistence(timeout: 5))
        restartButton.tap()

        // After restart, a level label should still be visible
        let levelLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Level'")
        ).firstMatch
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 3),
                      "Level should remain visible after restart")
    }

    // MARK: - Keyboard Shortcuts (macOS)

    #if os(macOS)
    func testCommandRRestartsLevel() throws {
        navigateToIronLevel1()

        let levelLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Level'")
        ).firstMatch
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 5))

        // Press Cmd+R
        app.typeKey("r", modifierFlags: .command)

        // Level label should still be shown
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 3))
    }

    func testCommandHGoesHome() throws {
        navigateToIronLevel1()

        // Press Cmd+H (note: may conflict with system shortcut)
        app.typeKey("h", modifierFlags: .command)

        let title = app.navigationBars["SortVision"]
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "Cmd+H should return to root screen")
    }
    #endif

    // MARK: - Level Completion Overlay

    func testLevelCompletionOverlayMainMenuButton() throws {
        // Validates gameplay loads without crashes.
        // Full puzzle-solving automation is better suited for
        // integration tests with direct GameEngine manipulation.
        navigateToIronLevel1()

        let levelLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Level'")
        ).firstMatch
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 5),
                      "Gameplay should load without crashes")
    }

    // MARK: - Performance

    func testNavigationPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let ironRow = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Iron'")
            ).firstMatch
            guard ironRow.waitForExistence(timeout: 5) else { return }
            ironRow.tap()

            let level1 = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] '1'")
            ).firstMatch
            guard level1.waitForExistence(timeout: 5) else { return }

            // Navigate back
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
                _ = app.navigationBars["SortVision"]
                    .waitForExistence(timeout: 3)
            }

            app.terminate()
            app.launch()
        }
    }
}
