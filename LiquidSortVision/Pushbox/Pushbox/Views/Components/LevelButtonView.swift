// LevelButtonView.swift
// Reusable level button component for the levels grid.

import SwiftUI

// MARK: - LevelButtonView

/// A reusable view that displays a level selection button in the grid.
/// Shows level number, star rating, and completion status.
/// Locked levels show a lock icon and are non-interactive.
/// Uses the system `.glass` button style per Apple HIG for iOS 26+.
struct LevelButtonView: View {
    
    // MARK: - Properties
    
    /// The level index (0-based).
    let levelIndex: Int
    
    /// Whether this level is currently active/selected.
    let isActive: Bool
    
    /// Whether this level has been completed.
    let isCompleted: Bool
    
    /// Star rating for this level (0-3).
    let starRating: Int
    
    /// Whether the user has used a solution credit on this level.
    let hasSolutionUnlocked: Bool
    
    /// Whether this level is unlocked (playable). Defaults to `true` for backward compatibility.
    var isUnlocked: Bool = true
    
    /// Message explaining what needs to be done to unlock this level.
    /// Shown when the user taps a locked level.
    var lockMessage: String?
    
    /// Action to execute when the level is selected.
    let onSelect: () -> Void
    
    // MARK: - State
    
    /// Whether the locked-level alert is presented.
    @State private var showLockedAlert = false
    
    // MARK: - Private Helpers
    
    private var foregroundColor: Color {
        if !isUnlocked { return .secondary }
        if isActive { return .blue }
        if isCompleted { return .green }
        return .primary
    }
    
    // MARK: - Body
    
    var body: some View {
        if isUnlocked {
            unlockedButton
        } else {
            lockedView
        }
    }
    
    // MARK: - Unlocked Button
    
    private var unlockedButton: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text("\(levelIndex + 1)")
                    #if os(iOS)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isActive ? Color.accentColor : .primary)
                    #else
                    .font(.subheadline.weight(.semibold))
                    #endif
                
                #if os(iOS)
                if starRating > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < starRating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(i < starRating ? Color.yellow : Color.secondary)
                        }
                    }
                }
                #else
                StarRatingView(rating: starRating)
                #endif
            }
            #if !os(iOS)
            .overlay(alignment: .topTrailing) {
                if hasSolutionUnlocked {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .offset(x: 4, y: -4)
                }
            }
            #endif
            #if os(iOS)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if hasSolutionUnlocked {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.accentColor : .clear,
                        lineWidth: isActive ? 2 : 0
                    )
            )
            #elseif os(visionOS)
            .foregroundStyle(foregroundColor)
            .frame(width: 64, height: 64)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .hoverEffect()
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12, style: .continuous))
            #else
            .foregroundStyle(foregroundColor)
            .padding(8)
            .frame(minWidth: 60, minHeight: 60)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            #endif
        }
        #if os(visionOS)
        .buttonStyle(.plain)
        #elseif os(iOS)
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        #else
        .buttonStyle(.glass)
        #endif
        .accessibilityLabel(
            "Level \(levelIndex + 1), \(isCompleted ? "completed" : "incomplete"), \(starRating) stars\(hasSolutionUnlocked ? ", solution unlocked" : "")"
        )
        .accessibilityValue(isActive ? "Selected" : "Not selected")
        .accessibilityHint("Double-tap to play this level")
    }
    
    // MARK: - Locked View
    
    private var lockedView: some View {
        Button {
            showLockedAlert = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                
                Text("\(levelIndex + 1)")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary.opacity(0.5))
            #if os(iOS)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            #elseif os(visionOS)
            .padding(8)
            .frame(width: 64, height: 64)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .hoverEffect()
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12, style: .continuous))
            #else
            .padding(16)
            .frame(minWidth: 60, minHeight: 60)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            #endif
        }
        #if os(visionOS)
        .buttonStyle(.plain)
        #elseif os(iOS)
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        #else
        .buttonStyle(.glass)
        #endif
        .opacity(0.6)
        .accessibilityLabel("Level \(levelIndex + 1), locked")
        .accessibilityHint(lockMessage ?? "Complete more levels in the previous group to unlock")
        .alert("Level Locked", isPresented: $showLockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockMessage ?? "Complete more levels to unlock this level.")
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        LevelButtonView(
            levelIndex: 0,
            isActive: false,
            isCompleted: false,
            starRating: 0,
            hasSolutionUnlocked: false,
            onSelect: {}
        )
        LevelButtonView(
            levelIndex: 1,
            isActive: true,
            isCompleted: true,
            starRating: 2,
            hasSolutionUnlocked: true,
            onSelect: {}
        )
        LevelButtonView(
            levelIndex: 2,
            isActive: false,
            isCompleted: true,
            starRating: 3,
            hasSolutionUnlocked: false,
            onSelect: {}
        )
        LevelButtonView(
            levelIndex: 3,
            isActive: false,
            isCompleted: false,
            starRating: 0,
            hasSolutionUnlocked: false,
            isUnlocked: false,
            onSelect: {}
        )
    }
    .padding()
}
