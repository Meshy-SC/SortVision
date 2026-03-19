import Foundation

/// Protocol abstracting sound playback for dependency injection.
///
/// Allows `GameEngine` and other consumers to play sounds without
/// a hard dependency on `SoundManager`, enabling:
/// - Unit testing with a silent mock
/// - Preview-friendly sound stubs
/// - Future alternative audio backends
///
/// ## Default Implementation
/// `SoundManager` conforms to this protocol, and its `shared`
/// singleton is the production implementation.
///
/// ## Testing
/// ```swift
/// final class MockSoundPlayer: SoundPlayable {
///     var playedSounds: [GameSound] = []
///     func play(_ sound: GameSound) { playedSounds.append(sound) }
/// }
/// ```
@MainActor
protocol SoundPlayable: AnyObject {
    /// Plays a sound effect if sound is enabled.
    func play(_ sound: GameSound)
}

// MARK: - SoundManager Conformance

extension SoundManager: SoundPlayable {}
