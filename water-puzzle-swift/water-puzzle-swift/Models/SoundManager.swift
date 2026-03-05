import SpriteKit

/// Sound effect identifiers matching the original Unity audio clips.
enum GameSound: String, Sendable {
    case pop = "pop_sound_effect"     // Tube lift (pending)
    case push = "push_sound_effect"   // Tube put down
    case water = "water"              // Water pouring
    case correct = "Correct"          // Correct action
    case win = "Epic"                 // Level complete fanfare

    var fileExtension: String {
        switch self {
        case .pop, .push: return "mp3"
        case .water, .correct, .win: return "wav"
        }
    }

    var fileName: String {
        "\(rawValue).\(fileExtension)"
    }
}

/// Manages SpriteKit sound playback, checking the global sound toggle.
final class SoundManager {
    static let shared = SoundManager()

    private var cachedActions: [GameSound: SKAction] = [:]

    private init() {
        // Pre-load all sound actions for low-latency playback
        for sound in [GameSound.pop, .push, .water, .correct, .win] {
            cachedActions[sound] = SKAction.playSoundFileNamed(
                sound.fileName, waitForCompletion: false
            )
        }
    }

    func play(_ sound: GameSound, on node: SKNode) {
        guard GameManager.shared.soundEnabled else { return }
        if let action = cachedActions[sound] {
            node.run(action)
        }
    }
}
