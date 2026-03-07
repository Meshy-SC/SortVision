import SpriteKit
import Testing

@testable import water_puzzle_swift

@Suite("SoundManager")
@MainActor
struct SoundManagerTests {

    @Test("soundEnabled reflects UserDefaults value")
    func soundEnabledReadsUserDefaults() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.soundEnabledKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(true, forKey: GameManager.soundEnabledKey)
        #expect(SoundManager.shared.soundEnabled == true)

        UserDefaults.standard.set(false, forKey: GameManager.soundEnabledKey)
        #expect(SoundManager.shared.soundEnabled == false)
    }

    @Test("play does not crash when sound is disabled")
    func playWithSoundDisabled() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.soundEnabledKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(false, forKey: GameManager.soundEnabledKey)
        let node = SKNode()
        // Should not throw or crash
        SoundManager.shared.play(.pop, on: node)
    }
}

// MARK: - GameSound Tests

@Suite("GameSound Enum")
struct GameSoundTests {

    @Test("All sounds have correct file extensions",
          arguments: [
            (GameSound.pop, "mp3"),
            (.push, "mp3"),
            (.water, "wav"),
            (.win, "wav"),
          ])
    func fileExtensions(sound: GameSound, expectedExt: String) {
        #expect(sound.fileExtension == expectedExt)
    }

    @Test("fileName combines rawValue and extension",
          arguments: GameSound.allCases)
    func fileNameFormat(sound: GameSound) {
        #expect(sound.fileName == "\(sound.rawValue).\(sound.fileExtension)")
    }

    @Test("All four sound effects are defined")
    func allSoundsDefined() {
        #expect(GameSound.allCases.count == 4)
    }
}
