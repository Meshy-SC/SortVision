import RealityKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - RealityKit Color Bridge

/// Extends the existing `ColorPalette` (SpriteKit) with RealityKit-compatible
/// SIMD color values. The canonical palette stays in `ColorPalette.swift`;
/// this file only adds a lightweight 3D projection.
enum ColorPalette3D {

    // MARK: - SIMD Colors

    /// The 11-color palette as SIMD4<Float> (linear RGB, alpha = 1).
    /// Index order is identical to `ColorPalette.colors`.
    static let colors: [SIMD4<Float>] = [
        SIMD4<Float>(0.180, 0.800, 0.443, 1), // 0: Green
        SIMD4<Float>(0.960, 0.800, 0.120, 1), // 1: Yellow
        SIMD4<Float>(0.827, 0.329, 0.000, 1), // 2: Orange
        SIMD4<Float>(0.161, 0.502, 0.725, 1), // 3: Blue
        SIMD4<Float>(0.608, 0.811, 0.218, 1), // 4: Lime
        SIMD4<Float>(0.950, 0.850, 0.100, 1), // 5: Bright Yellow
        SIMD4<Float>(0.092, 0.528, 0.329, 1), // 6: Dark Green
        SIMD4<Float>(0.086, 0.627, 0.522, 1), // 7: Teal
        SIMD4<Float>(0.557, 0.267, 0.678, 1), // 8: Purple
        SIMD4<Float>(0.910, 0.263, 0.576, 1), // 9: Pink
        SIMD4<Float>(0.498, 0.549, 0.553, 1), // 10: Gray
    ]

    /// Returns the SIMD color for a given `groupId`, or white if out of range.
    static func color(for groupId: Int) -> SIMD4<Float> {
        guard groupId >= 0, groupId < colors.count else {
            return SIMD4<Float>(1, 1, 1, 1)
        }
        return colors[groupId]
    }

    // MARK: - Material Helpers

    /// Creates a physically-based material that looks like colored liquid.
    /// Slightly glossy, saturated, non-metallic.
    static func liquidMaterial(for groupId: Int) -> PhysicallyBasedMaterial {
        let rgba = color(for: groupId)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(
            red: CGFloat(rgba.x),
            green: CGFloat(rgba.y),
            blue: CGFloat(rgba.z),
            alpha: 1.0
        ))
        material.roughness = .init(floatLiteral: 0.25)
        material.metallic = .init(floatLiteral: 0.0)
        return material
    }

    /// A translucent glass material with a subtle blue tint.
    /// Opacity tuned so the bottle silhouette is clearly visible
    /// while liquid colors show through.
    static func glassMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(
            red: 0.70, green: 0.78, blue: 0.88, alpha: 0.35
        ))
        material.roughness = .init(floatLiteral: 0.05)
        material.metallic = .init(floatLiteral: 0.0)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.28))
        return material
    }

    /// A brighter material for tube rims / inner edge details.
    static func glassRimMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(white: 0.92, alpha: 0.7))
        material.roughness = .init(floatLiteral: 0.1)
        material.metallic = .init(floatLiteral: 0.1)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.55))
        return material
    }

    /// A dark gray metallic material for the bottle cap/rim at the top.
    static func capMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(
            red: 0.35, green: 0.38, blue: 0.42, alpha: 1.0
        ))
        material.roughness = .init(floatLiteral: 0.4)
        material.metallic = .init(floatLiteral: 0.3)
        return material
    }
}
