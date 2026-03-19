import CoreGraphics
import Foundation

/// Orchestrates the multi-phase pour animation sequence.
///
/// Extracted from `GameEngine` to separate animation timing/choreography
/// from game state management. The animator drives tube transforms
/// (lift, tilt, translate) and liquid value interpolation through
/// four sequential phases:
///
/// 1. **Lift** — Raise the source tube above others
/// 2. **Tilt & Align** — Rotate toward target and position the pouring lip
/// 3. **Pour** — Stream liquid while interpolating volume values
/// 4. **Return** — Animate back to the resting position
///
/// ## Architecture
/// The animator operates on `TubeState` objects directly (they are reference
/// types) and reports phase transitions via the `PourAnimatorDelegate` protocol.
@MainActor
struct PourAnimator {

    // MARK: - Configuration

    /// Tilt angle — slightly past horizontal for a natural pour.
    static let pourTiltAngle: CGFloat = 95.0 * .pi / 180.0

    // MARK: - Animation Helpers

    /// Drives a closure with `t` from 0→1 over `duration` seconds at ~60fps.
    ///
    /// - Parameters:
    ///   - duration: Total animation duration in seconds.
    ///   - frameDuration: Nanoseconds per frame (~16ms for 60fps).
    ///   - update: Called each frame with progress `t` in 0…1.
    static func animateValue(
        duration: Double,
        frameDuration: UInt64 = 16_000_000,
        update: (CGFloat) -> Void
    ) async {
        let totalFrames = Int(duration / (Double(frameDuration) / 1_000_000_000.0))
        for frame in 1...max(totalFrames, 1) {
            guard !Task.isCancelled else { return }
            let t = CGFloat(frame) / CGFloat(totalFrames)
            update(min(t, 1.0))
            try? await Task.sleep(nanoseconds: frameDuration)
        }
    }

    /// Smooth ease-in-out curve (Hermite interpolation).
    ///
    /// Maps input `t` (0…1) to a smoothed output using: `t² × (3 - 2t)`
    static func easeInOut(_ t: CGFloat) -> CGFloat {
        t * t * (3.0 - 2.0 * t)
    }
}
