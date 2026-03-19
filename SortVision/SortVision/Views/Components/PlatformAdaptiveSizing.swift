import CoreGraphics

/// Platform-adaptive sizing for celebration and overlay views.
///
/// Provides consistent font sizes and spacing that automatically
/// adapt between iOS, macOS, and visionOS. visionOS uses larger
/// values to account for spatial viewing distance.
///
/// ## Usage
/// Conform a view to this protocol to access the sizing constants:
/// ```swift
/// struct MyOverlay: View, PlatformAdaptiveSizing { ... }
/// ```
protocol PlatformAdaptiveSizing {
    var titleFontSize: CGFloat { get }
    var starSize: CGFloat { get }
    var starSpacing: CGFloat { get }
    var scoreBonusFontSize: CGFloat { get }
    var totalScoreFontSize: CGFloat { get }
    var movesFontSize: CGFloat { get }
}

/// Default implementation providing platform-specific sizing values.
extension PlatformAdaptiveSizing {
    var titleFontSize: CGFloat {
        #if os(visionOS)
        42
        #else
        32
        #endif
    }

    var starSize: CGFloat {
        #if os(visionOS)
        60
        #else
        48
        #endif
    }

    var starSpacing: CGFloat {
        #if os(visionOS)
        24
        #else
        16
        #endif
    }

    var scoreBonusFontSize: CGFloat {
        #if os(visionOS)
        36
        #else
        28
        #endif
    }

    var totalScoreFontSize: CGFloat {
        #if os(visionOS)
        28
        #else
        22
        #endif
    }

    var movesFontSize: CGFloat {
        #if os(visionOS)
        22
        #else
        17
        #endif
    }
}
