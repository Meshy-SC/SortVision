// WorldRowView.swift
// Reusable world selection row component for the sidebar.

import SwiftUI

// MARK: - WorldRowView

/// A standard sidebar row for world selection.
///
/// Designed for use inside a `List(selection:)` which handles
/// visual selection state automatically — following visionOS HIG
/// sidebar patterns. Uses a `Label` layout with icon and text.
struct WorldRowView: View {
    
    // MARK: - Properties
    
    /// The world to display.
    let world: World
    
    /// Number of completed levels in this world.
    let completedCount: Int
    
    /// Total number of levels in this world.
    let totalLevels: Int
    
    /// Whether the world is unlocked. Defaults to `true` for backward compatibility.
    var isUnlocked: Bool = true
    
    // MARK: - Computed Properties
    
    /// Whether all levels in this world are completed.
    private var isWorldCompleted: Bool {
        totalLevels > 0 && completedCount == totalLevels
    }
    
    /// Icon name based on world state.
    private var iconName: String {
        if !isUnlocked { return "lock.fill" }
        if isWorldCompleted { return "checkmark.circle.fill" }
        return "cube.box"
    }
    
    /// Icon color based on world state.
    private var iconColor: Color {
        if !isUnlocked { return .secondary }
        if isWorldCompleted { return .green }
        return .blue
    }
    
    // MARK: - Body
    
    var body: some View {
        Label {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(world.title)
                        .font(.headline)
                    Text(world.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(completedCount) of \(totalLevels)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
        }
        .opacity(isUnlocked ? 1.0 : 0.6)
        .accessibilityLabel("\(world.title) world, \(isUnlocked ? (isWorldCompleted ? "completed" : "incomplete") : "locked"), \(completedCount) of \(totalLevels)")
        .accessibilityHint(isUnlocked ? "Double-tap to select this world and view its levels" : "Complete more levels in the previous world to unlock")
    }
}
