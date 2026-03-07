import Foundation

/// Mirrors the Unity GameMode enum: Easy, Normal, Hard.
/// Adds Expert for the fourth level file (levels-ex.json).
enum GameMode: Int, CaseIterable, Codable, Sendable, Identifiable {
    case easy = 0
    case normal = 1
    case hard = 2
    case expert = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        case .expert: "Expert"
        }
    }

    /// JSON resource filename (without extension).
    var levelResourceName: String {
        switch self {
        case .easy: "levels"
        case .normal: "levels-normal"
        case .hard: "levels-hard"
        case .expert: "levels-ex"
        }
    }

    /// UserDefaults key for completed level tracking.
    var completionKey: String {
        "\(self)_Level_Complete"
    }
}
