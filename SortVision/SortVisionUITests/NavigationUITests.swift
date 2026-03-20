import XCTest

/// UI tests for the app's navigation flow.
///
/// Validates that the full navigation path works correctly:
/// StageSelection (root) → LevelGrid → Gameplay
final class NavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Root Screen

    func testRootScreenDisplaysNavigationTitle() throws {
        let title = app.navigationBars["SortVision"]
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "Root screen should display 'SortVision' navigation title")
    }

    func testRootScreenDisplaysWorlds() throws {
        // Iron is always the first world and always accessible
        let ironRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Iron'")
        ).firstMatch
        XCTAssertTrue(ironRow.waitForExistence(timeout: 5),
                      "Iron world should be visible on the root screen")
    }

    func testRootScreenDisplaysSettingsButton() throws {
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5),
                      "Settings button should be visible on root screen")
    }

    // MARK: - Navigation Flow: Stage → Level Grid

    func testNavigateToLevelGrid() throws {
        let ironRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Iron'")
        ).firstMatch
        XCTAssertTrue(ironRow.waitForExistence(timeout: 5))
        ironRow.tap()

        // Should show level grid with Level 1 tile
        let levelTile = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] '1'")
        ).firstMatch
        XCTAssertTrue(levelTile.waitForExistence(timeout: 5),
                      "Level tile should be visible in the grid")
    }

    // MARK: - Navigation Flow: Level Grid → Gameplay

    func testNavigateToGameplay() throws {
        // Navigate to Iron level grid
        let ironRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Iron'")
        ).firstMatch
        XCTAssertTrue(ironRow.waitForExistence(timeout: 5))
        ironRow.tap()

        // Tap Level 1
        let level1 = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] '1'")
        ).firstMatch
        XCTAssertTrue(level1.waitForExistence(timeout: 5))
        level1.tap()

        // Should show gameplay with level header
        let levelHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Level'")
        ).firstMatch
        XCTAssertTrue(levelHeader.waitForExistence(timeout: 5),
                      "Should navigate to gameplay with a level header")
    }

    // MARK: - Gameplay Navigation

    func testHomeButtonReturnsToRoot() throws {
        // Navigate to gameplay
        let ironRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Iron'")
        ).firstMatch
        XCTAssertTrue(ironRow.waitForExistence(timeout: 5))
        ironRow.tap()

        let level1 = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] '1'")
        ).firstMatch
        XCTAssertTrue(level1.waitForExistence(timeout: 5))
        level1.tap()

        // Tap Home button
        let homeButton = app.buttons["Home"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 5))
        homeButton.tap()

        // Should return to root with navigation title
        let title = app.navigationBars["SortVision"]
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "Tapping Home should return to the root screen")
    }

    // MARK: - Accessibility

    func testWorldRowsHaveAccessibilityLabels() throws {
        let ironRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Iron'")
        ).firstMatch
        XCTAssertTrue(ironRow.waitForExistence(timeout: 5),
                      "Iron world row should have an accessibility label")
    }
}
