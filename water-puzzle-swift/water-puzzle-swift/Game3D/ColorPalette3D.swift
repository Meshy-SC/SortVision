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

    /// 12-color palette based on Apple's system colors (HIG).
    ///
    /// Apple designed these to be maximally distinguishable from each other
    /// across all lighting conditions and for users with color vision
    /// differences. Ordering alternates warm/cool hues so colours that
    /// commonly appear together in early levels are easy to tell apart.
    ///
    /// sRGB values sourced from Apple Human Interface Guidelines (iOS light).
    static let colors: [SIMD4<Float>] = [
        // 0  — Red          systemRed     (255,  59,  48)
        SIMD4<Float>(1.000, 0.231, 0.188, 1),
        // 1  — Blue         systemBlue    (  0, 122, 255)
        SIMD4<Float>(0.000, 0.478, 1.000, 1),
        // 2  — Yellow       systemYellow  (255, 204,   0)
        SIMD4<Float>(1.000, 0.800, 0.000, 1),
        // 3  — Green        systemGreen   ( 52, 199,  89)
        SIMD4<Float>(0.204, 0.780, 0.349, 1),
        // 4  — Purple       systemPurple  (175,  82, 222)
        SIMD4<Float>(0.686, 0.322, 0.871, 1),
        // 5  — Orange       systemOrange  (255, 149,   0)
        SIMD4<Float>(1.000, 0.584, 0.000, 1),
        // 6  — Cyan         systemCyan    ( 50, 173, 230)
        SIMD4<Float>(0.196, 0.678, 0.902, 1),
        // 7  — Pink         systemPink    (255,  45,  85)
        SIMD4<Float>(1.000, 0.176, 0.333, 1),
        // 8  — Mint         systemMint    (  0, 199, 190)
        SIMD4<Float>(0.000, 0.780, 0.745, 1),
        // 9  — Indigo       systemIndigo  ( 88,  86, 214)
        SIMD4<Float>(0.345, 0.337, 0.839, 1),
        // 10 — Brown        systemBrown   (162, 132,  94)
        SIMD4<Float>(0.635, 0.518, 0.369, 1),
        // 11 — Teal         systemTeal    ( 48, 176, 199)
        SIMD4<Float>(0.188, 0.690, 0.780, 1),
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
