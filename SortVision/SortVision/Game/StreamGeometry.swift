import CoreGraphics

/// Shared liquid stream rendering calculations.
///
/// Provides the stream thickness ramp function used by both
/// `LiquidStreamView` and `LiquidNeckSegmentView` to ensure
/// consistent visual behavior across stream components.
enum StreamGeometry {

    /// Default stream line width.
    static let streamWidth: CGFloat = 5

    /// Calculates stream thickness multiplier based on pour progress.
    ///
    /// The thickness ramps up quickly at the start, stays at full width
    /// during the main pour, then tapers off at the end:
    /// - 0.00–0.08: Ramp up (0→1)
    /// - 0.08–0.88: Full thickness (1.0)
    /// - 0.88–1.00: Taper off (1→0)
    ///
    /// - Parameter progress: Pour progress from 0 to 1.
    /// - Returns: Thickness multiplier from 0 to 1.
    static func thickness(for progress: CGFloat) -> CGFloat {
        switch progress {
        case ..<0.08:  progress / 0.08
        case 0.88...:  (1.0 - progress) / 0.12
        default:       1.0
        }
    }
}
