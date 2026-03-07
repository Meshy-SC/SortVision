import SpriteKit

/// Sound effect identifiers matching the original Unity audio clips.
///
/// Each case maps to an audio file in the app bundle via its `rawValue` and `fileExtension`.
enum GameSound: String, CaseIterable, Sendable {
    case pop = "pop_sound_effect"     // Tube lift (pending)
    case push = "push_sound_effect"   // Tube put down
    case water = "water"              // Water pouring
    case win = "Epic"                 // Level complete fanfare

    /// Audio file format extension.
    var fileExtension: String {
        switch self {
        case .pop, .push: return "mp3"
        case .water, .win: return "wav"
        }
    }

    /// Complete filename including extension (e.g., `"pop_sound_effect.mp3"`).
    var fileName: String {
        "\(rawValue).\(fileExtension)"
    }
}

/// Manages SpriteKit sound effect playback with caching and preference support.
///
/// ## Architecture Notes
/// - Reads the sound-enabled preference directly from `UserDefaults`
/// - Does **not** depend on `GameManager` — both independently share the same
///   UserDefaults key (`"soundEnabled"`) to stay in sync without coupling
/// - Pre-loads all `SKAction` sound actions at initialization for low-latency playback
///
/// ## Usage
/// ```swift
/// SoundManager.shared.play(.pop, on: someNode)
/// ```
@MainActor
final class SoundManager {

    // MARK: - Singleton

    static let shared = SoundManager()

    // MARK: - Cached Actions

    /// Pre-loaded sound actions indexed by sound type for instant playback.
    private var cachedActions: [GameSound: SKAction] = [:]

    // MARK: - Sound Preference

    /// Whether sound effects are enabled.
    ///
    /// Reads directly from `UserDefaults` using the same key as `GameManager.soundEnabled`.
    /// This keeps audio playback in sync with the UI toggle without any direct dependency.
    var soundEnabled: Bool {
        UserDefaults.standard.bool(forKey: GameManager.soundEnabledKey)
    }

    // MARK: - Initialization

    private init() {
        // Pre-load all sound actions for low-latency playback
        for sound in GameSound.allCases {
            cachedActions[sound] = SKAction.playSoundFileNamed(
                sound.fileName, waitForCompletion: false
            )
        }
    }

    // MARK: - Playback

    /// Plays a sound effect on the given SpriteKit node, if sound is enabled.
    ///
    /// Sound actions are pre-cached at initialization, so this method has
    /// minimal overhead — it only checks the UserDefaults flag and runs the action.
    ///
    /// - Parameters:
    ///   - sound: The sound effect to play.
    ///   - node: The `SKNode` on which to run the sound action.
    func play(_ sound: GameSound, on node: SKNode) {
        guard soundEnabled, let action = cachedActions[sound] else { return }
        node.run(action)
    }
}
