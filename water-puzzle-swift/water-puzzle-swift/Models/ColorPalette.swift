import SpriteKit

/// The exact 11-color palette extracted from the Unity Liquid.prefab's _groupColors array.
/// Each index corresponds to a groupId used in the level JSON data.
enum ColorPalette {
    static let colors: [SKColor] = [
        SKColor(red: 0.180, green: 0.800, blue: 0.443, alpha: 1), // 0: Green
        SKColor(red: 0.960, green: 0.800, blue: 0.120, alpha: 1), // 1: Yellow (boosted for contrast)
        SKColor(red: 0.827, green: 0.329, blue: 0.000, alpha: 1), // 2: Orange
        SKColor(red: 0.161, green: 0.502, blue: 0.725, alpha: 1), // 3: Blue
        SKColor(red: 0.608, green: 0.811, blue: 0.218, alpha: 1), // 4: Lime
        SKColor(red: 0.950, green: 0.850, blue: 0.100, alpha: 1), // 5: Bright Yellow (shifted warmer for contrast & distinction from Yellow)
        SKColor(red: 0.092, green: 0.528, blue: 0.329, alpha: 1), // 6: Dark Green
        SKColor(red: 0.086, green: 0.627, blue: 0.522, alpha: 1), // 7: Teal
        SKColor(red: 0.557, green: 0.267, blue: 0.678, alpha: 1), // 8: Purple
        SKColor(red: 0.910, green: 0.263, blue: 0.576, alpha: 1), // 9: Pink
        SKColor(red: 0.498, green: 0.549, blue: 0.553, alpha: 1), // 10: Gray
    ]

    static func color(for groupId: Int) -> SKColor {
        guard groupId >= 0, groupId < colors.count else { return .white }
        return colors[groupId]
    }
}
