import AVFoundation
import Foundation

/// Sound effect identifiers matching the original audio clips.
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
}

/// Sound manager using AVAudioPlayer for fire-and-forget playback.
///
/// ## Usage
/// ```swift
/// SoundManager.shared.play(.pop)
/// ```
@MainActor
final class SoundManager {

    // MARK: - Singleton

    static let shared = SoundManager()

    // MARK: - Cached Players

    /// Pre-loaded audio data indexed by sound type for low-latency playback.
    private var cachedData: [GameSound: Data] = [:]

    /// Active players — kept alive until playback finishes.
    private var activePlayers: [AVAudioPlayer] = []

    // MARK: - Sound Preference

    /// Whether sound effects are enabled (reads same UserDefaults key as GameManager).
    var soundEnabled: Bool {
        UserDefaults.standard.bool(forKey: GameManager.soundEnabledKey)
    }

    // MARK: - Init

    private init() {
        for sound in GameSound.allCases {
            if let url = Bundle.main.url(
                forResource: sound.rawValue,
                withExtension: sound.fileExtension
            ),
               let data = try? Data(contentsOf: url)
            {
                cachedData[sound] = data
            }
        }
    }

    // MARK: - Playback

    /// Plays a sound effect if sound is enabled.
    func play(_ sound: GameSound) {
        guard soundEnabled, let data = cachedData[sound] else { return }

        do {
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            player.play()

            activePlayers.append(player)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(player.duration + 0.5))
                self?.activePlayers.removeAll { $0 === player }
            }
        } catch {
            // Silently fail — sound is non-critical
        }
    }
}
