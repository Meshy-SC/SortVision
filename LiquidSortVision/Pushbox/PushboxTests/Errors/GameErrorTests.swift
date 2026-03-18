// GameErrorTests.swift
// Tests for the GameError enum.

import Testing
import Foundation
@testable import Pushbox

@Suite("GameError")
struct GameErrorTests {

    @Test("levelFileNotFound includes world name in description")
    func levelFileNotFoundDescription() {
        let error = GameError.levelFileNotFound(worldName: "World5")
        #expect(error.errorDescription?.contains("World5") == true)
    }

    @Test("levelFileParsingFailed includes world name and underlying error")
    func levelFileParsingFailedDescription() {
        let error = GameError.levelFileParsingFailed(
            worldName: "World1",
            underlyingErrorDescription: "invalid JSON"
        )
        #expect(error.errorDescription?.contains("World1") == true)
        #expect(error.errorDescription?.contains("invalid JSON") == true)
    }

    @Test("emptyWorldFile includes world name in description")
    func emptyWorldFileDescription() {
        let error = GameError.emptyWorldFile(worldName: "World3")
        #expect(error.errorDescription?.contains("World3") == true)
    }

    @Test("All error cases provide recovery suggestions",
          arguments: [
            GameError.levelFileNotFound(worldName: "Test"),
            GameError.levelFileParsingFailed(worldName: "Test", underlyingErrorDescription: "err"),
            GameError.emptyWorldFile(worldName: "Test")
          ])
    func recoverySuggestionExists(error: GameError) {
        #expect(error.recoverySuggestion != nil)
        #expect(!error.recoverySuggestion!.isEmpty)
    }

    @Test("All error cases provide error descriptions",
          arguments: [
            GameError.levelFileNotFound(worldName: "Test"),
            GameError.levelFileParsingFailed(worldName: "Test", underlyingErrorDescription: "err"),
            GameError.emptyWorldFile(worldName: "Test")
          ])
    func errorDescriptionExists(error: GameError) {
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }
}
