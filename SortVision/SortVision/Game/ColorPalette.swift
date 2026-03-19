import SwiftUI

/// Canonical color palette for the SortVision puzzle.
///
/// 12-color palette based on Apple's system colors (HIG).
/// Apple designed these to be maximally distinguishable from each other
/// and for users with color vision differences.
enum ColorPalette {

    // MARK: - Colors

    /// 12-color palette ordered to alternate warm/cool hues so colours
    /// that commonly appear together in early levels are easy to tell apart.
    static let colors: [Color] = [
        // 0  — Red
        Color(red: 1.000, green: 0.231, blue: 0.188),
        // 1  — Blue
        Color(red: 0.000, green: 0.478, blue: 1.000),
        // 2  — Yellow
        Color(red: 1.000, green: 0.800, blue: 0.000),
        // 3  — Green
        Color(red: 0.204, green: 0.780, blue: 0.349),
        // 4  — Purple
        Color(red: 0.686, green: 0.322, blue: 0.871),
        // 5  — Orange
        Color(red: 1.000, green: 0.584, blue: 0.000),
        // 6  — Cyan
        Color(red: 0.196, green: 0.678, blue: 0.902),
        // 7  — Pink
        Color(red: 1.000, green: 0.176, blue: 0.333),
        // 8  — Mint
        Color(red: 0.000, green: 0.780, blue: 0.745),
        // 9  — Indigo
        Color(red: 0.345, green: 0.337, blue: 0.839),
        // 10 — Brown
        Color(red: 0.635, green: 0.518, blue: 0.369),
        // 11 — Teal
        Color(red: 0.188, green: 0.690, blue: 0.780),
    ]

    /// Returns the color for a given `groupId`, or gray if out of range.
    static func color(for groupId: Int) -> Color {
        guard groupId >= 0, groupId < colors.count else {
            return .gray
        }
        return colors[groupId]
    }
}
