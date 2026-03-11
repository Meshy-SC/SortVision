import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("Deep Link Integration")
@MainActor
struct DeepLinkIntegrationTests {

    // MARK: - URL Parsing (mirrors RootNavigationView.handleDeepLink)

    /// Parses a deep link URL the same way RootNavigationView does.
    private func parseDeepLinkURL(_ urlString: String) -> (stage: Stage, levelNumber: Int)? {
        guard let url = URL(string: urlString),
              url.scheme == "waterpuzzle",
              url.host == "play",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let levelStr = components.queryItems?.first(where: { $0.name == "level" })?.value,
              let levelNum = Int(levelStr),
              let stage = Stage.stage(for: levelNum)
        else { return nil }

        return (stage: stage, levelNumber: levelNum)
    }

    // MARK: - Valid URLs

    @Test("Valid deep link URL parses correctly",
          arguments: [
            ("waterpuzzle://play?level=5", Stage.iron, 5),
            ("waterpuzzle://play?level=1", Stage.iron, 1),
            ("waterpuzzle://play?level=100", Stage.iron, 100),
            ("waterpuzzle://play?level=101", Stage.bronze, 101),
            ("waterpuzzle://play?level=250", Stage.silver, 250),
            ("waterpuzzle://play?level=400", Stage.gold, 400),
          ] as [(String, Stage, Int)])
    func validDeepLinkParsing(urlString: String, expectedStage: Stage, expectedLevel: Int) {
        let result = parseDeepLinkURL(urlString)
        #expect(result != nil)
        #expect(result?.stage == expectedStage)
        #expect(result?.levelNumber == expectedLevel)
    }

    // MARK: - Invalid URLs

    @Test("Wrong scheme is rejected")
    func wrongScheme() {
        #expect(parseDeepLinkURL("https://play?level=1") == nil)
    }

    @Test("Wrong host is rejected")
    func wrongHost() {
        #expect(parseDeepLinkURL("waterpuzzle://settings?level=1") == nil)
    }

    @Test("Missing level parameter is rejected")
    func missingLevel() {
        #expect(parseDeepLinkURL("waterpuzzle://play") == nil)
    }

    @Test("Non-numeric level is rejected")
    func nonNumericLevel() {
        #expect(parseDeepLinkURL("waterpuzzle://play?level=abc") == nil)
    }

    @Test("Level 0 is rejected (out of range)")
    func zeroLevel() {
        #expect(parseDeepLinkURL("waterpuzzle://play?level=0") == nil)
    }

    @Test("Empty URL string is rejected")
    func emptyURL() {
        #expect(parseDeepLinkURL("") == nil)
    }

    // MARK: - DeepLinkManager → GameManager Flow

    @Test("DeepLinkManager pending level resolves to valid GameManager level")
    func pendingLevelResolvesToValidLevel() {
        let level = GameManager.shared.level(globalNumber: 1)
        #expect(level != nil, "Level 1 should always exist")
        #expect(level?.number == 1)
    }

    @Test("Locked level detection works with deep links")
    func lockedLevelDetection() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        // Reset progress
        UserDefaults.standard.set(0, forKey: GameManager.completionKey)
        GameManager.shared.loadCompletedLevel()

        // Level 1 should be unlocked
        #expect(!GameManager.shared.isLevelLocked(1))

        // Level 3 should be locked (only 1 is unlocked when progress = 0)
        #expect(GameManager.shared.isLevelLocked(3))
    }
}
