import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("Deep Link Integration")
@MainActor
struct DeepLinkIntegrationTests {

    // MARK: - URL Parsing (mirrors RootNavigationView.handleDeepLink)

    /// Parses a deep link URL the same way RootNavigationView does.
    private func parseDeepLinkURL(_ urlString: String) -> (mode: GameMode, levelNumber: Int)? {
        guard let url = URL(string: urlString),
              url.scheme == "waterpuzzle",
              url.host == "play",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let modeStr = components.queryItems?.first(where: { $0.name == "mode" })?.value,
              let modeRaw = Int(modeStr),
              let mode = GameMode(rawValue: modeRaw),
              let levelStr = components.queryItems?.first(where: { $0.name == "level" })?.value,
              let levelNum = Int(levelStr)
        else { return nil }

        return (mode: mode, levelNumber: levelNum)
    }

    // MARK: - Valid URLs

    @Test("Valid deep link URL parses correctly",
          arguments: [
            ("waterpuzzle://play?mode=0&level=5", GameMode.easy, 5),
            ("waterpuzzle://play?mode=1&level=1", GameMode.normal, 1),
            ("waterpuzzle://play?mode=2&level=100", GameMode.hard, 100),
            ("waterpuzzle://play?mode=3&level=42", GameMode.expert, 42),
          ] as [(String, GameMode, Int)])
    func validDeepLinkParsing(urlString: String, expectedMode: GameMode, expectedLevel: Int) {
        let result = parseDeepLinkURL(urlString)
        #expect(result != nil)
        #expect(result?.mode == expectedMode)
        #expect(result?.levelNumber == expectedLevel)
    }

    // MARK: - Invalid URLs

    @Test("Wrong scheme is rejected")
    func wrongScheme() {
        #expect(parseDeepLinkURL("https://play?mode=0&level=1") == nil)
    }

    @Test("Wrong host is rejected")
    func wrongHost() {
        #expect(parseDeepLinkURL("waterpuzzle://settings?mode=0&level=1") == nil)
    }

    @Test("Missing mode parameter is rejected")
    func missingMode() {
        #expect(parseDeepLinkURL("waterpuzzle://play?level=1") == nil)
    }

    @Test("Missing level parameter is rejected")
    func missingLevel() {
        #expect(parseDeepLinkURL("waterpuzzle://play?mode=0") == nil)
    }

    @Test("Invalid mode value is rejected")
    func invalidMode() {
        #expect(parseDeepLinkURL("waterpuzzle://play?mode=99&level=1") == nil)
    }

    @Test("Non-numeric mode is rejected")
    func nonNumericMode() {
        #expect(parseDeepLinkURL("waterpuzzle://play?mode=easy&level=1") == nil)
    }

    @Test("Non-numeric level is rejected")
    func nonNumericLevel() {
        #expect(parseDeepLinkURL("waterpuzzle://play?mode=0&level=abc") == nil)
    }

    @Test("Empty URL string is rejected")
    func emptyURL() {
        #expect(parseDeepLinkURL("") == nil)
    }

    // MARK: - DeepLinkManager → GameManager Flow

    @Test("DeepLinkManager pending level resolves to valid GameManager level")
    func pendingLevelResolvesToValidLevel() {
        let mode = GameMode.easy
        let number = 1
        let level = GameManager.shared.level(for: mode, number: number)

        #expect(level != nil, "Level 1 in Easy should always exist")
        #expect(level?.number == number)
    }

    @Test("Locked level detection works with deep links")
    func lockedLevelDetection() {
        let snapshot = UserDefaultsSnapshot(keys: [GameMode.easy.completionKey])
        defer { snapshot.restore() }

        // Reset progress
        UserDefaults.standard.set(0, forKey: GameMode.easy.completionKey)

        // Level 1 should be unlocked
        #expect(!GameManager.shared.isLevelLocked(mode: .easy, number: 1))

        // Level 3 should be locked (only 1 is unlocked when progress = 0)
        #expect(GameManager.shared.isLevelLocked(mode: .easy, number: 3))
    }
}
