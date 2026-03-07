import XCTest

/// UI tests for the app's navigation flow.
///
/// Validates that the full navigation path works correctly:
/// MainMenu → DifficultySelection → LevelGrid → Gameplay
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

    // MARK: - Main Menu

    func testMainMenuDisplaysPlayButton() throws {
        let playButton = app.buttons["PLAY"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5),
                      "PLAY button should be visible on the main menu")
    }

    func testMainMenuDisplaysSoundToggle() throws {
        // Sound toggle should be visible (either "Sound on" or "Sound off")
        let soundOn = app.buttons["Sound on"]
        let soundOff = app.buttons["Sound off"]
        XCTAssertTrue(soundOn.exists || soundOff.exists,
                      "Sound toggle button should be visible")
    }

    // MARK: - Navigation Flow

    func testNavigateToDifficultySelection() throws {
        app.buttons["PLAY"].tap()

        let header = app.staticTexts["Select Difficulty"]
        XCTAssertTrue(header.waitForExistence(timeout: 3),
                      "Should navigate to difficulty selection screen")
    }

    func testNavigateToLevelGrid() throws {
        app.buttons["PLAY"].tap()

        // Wait for and tap Easy difficulty
        let easyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Easy'")
        ).firstMatch
        XCTAssertTrue(easyButton.waitForExistence(timeout: 3))
        easyButton.tap()

        // Should show level grid
        let levelTile = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Level 1'")
        ).firstMatch
        XCTAssertTrue(levelTile.waitForExistence(timeout: 3),
                      "Level 1 tile should be visible in the grid")
    }

    func testNavigateToGameplay() throws {
        app.buttons["PLAY"].tap()

        let easyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Easy'")
        ).firstMatch
        XCTAssertTrue(easyButton.waitForExistence(timeout: 3))
        easyButton.tap()

        let level1 = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Level 1'")
        ).firstMatch
        XCTAssertTrue(level1.waitForExistence(timeout: 3))
        level1.tap()

        // Should show gameplay HUD
        let levelHeader = app.staticTexts["Level 1"]
        XCTAssertTrue(levelHeader.waitForExistence(timeout: 3),
                      "Should navigate to gameplay with Level 1 header")
    }

    // MARK: - Sound Toggle

    func testSoundToggleSwitchesState() throws {
        let soundOn = app.buttons["Sound on"]
        let soundOff = app.buttons["Sound off"]

        if soundOn.exists {
            soundOn.tap()
            XCTAssertTrue(soundOff.waitForExistence(timeout: 2),
                          "After tapping Sound on, it should become Sound off")
            // Restore
            soundOff.tap()
        } else if soundOff.exists {
            soundOff.tap()
            XCTAssertTrue(soundOn.waitForExistence(timeout: 2),
                          "After tapping Sound off, it should become Sound on")
            // Restore
            soundOn.tap()
        }
    }

    // MARK: - Gameplay Navigation

    func testHomeButtonReturnsToMainMenu() throws {
        // Navigate to gameplay
        app.buttons["PLAY"].tap()

        let easyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Easy'")
        ).firstMatch
        XCTAssertTrue(easyButton.waitForExistence(timeout: 3))
        easyButton.tap()

        let level1 = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Level 1'")
        ).firstMatch
        XCTAssertTrue(level1.waitForExistence(timeout: 3))
        level1.tap()

        // Tap Home button
        let homeButton = app.buttons["Home"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 3))
        homeButton.tap()

        // Should return to main menu
        let playButton = app.buttons["PLAY"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5),
                      "Tapping Home should return to the main menu")
    }

    // MARK: - Accessibility

    func testAllDifficultyButtonsHaveAccessibilityLabels() throws {
        app.buttons["PLAY"].tap()

        let difficulties = ["Easy", "Normal", "Hard", "Expert"]
        for difficulty in difficulties {
            let button = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", difficulty)
            ).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 3),
                          "\(difficulty) button should have accessibility label")
        }
    }
}
