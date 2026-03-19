import SwiftUI

// MARK: - LevelTileView

/// A single level cell in the level-select grid.
///
/// Displays the level number with star indicators for completed
/// levels, a lock icon for locked levels with a tap-to-show
/// unlock requirement alert. Matches ParkVision's LevelCell pattern.
struct LevelTileView: View {

    // MARK: Properties

    let levelNumber: Int
    let isLocked: Bool
    let isCompleted: Bool
    let starRating: Int
    let themeColor: Color
    var isCurrent: Bool = false
    var lockMessage: String?
    let action: () -> Void

    // MARK: State

    @State private var showLockedAlert = false

    // MARK: Body

    var body: some View {
        if isLocked {
            lockedView
        } else {
            unlockedButton
        }
    }

    // MARK: - Unlocked Button

    private var unlockedButton: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(levelNumber)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)

                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < starRating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundStyle(i < starRating ? Color.yellow : Color.secondary)
                    }
                }
            }
            #if os(visionOS)
            .frame(width: 64, height: 64)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .hoverEffect()
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12, style: .continuous))
            #elseif os(macOS)
            .padding(8)
            .frame(minWidth: 60, minHeight: 60)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            #else
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            #endif
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCurrent ? Color.accentColor : .clear,
                        lineWidth: isCurrent ? 2 : 0
                    )
            )
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #else
        .buttonStyle(.plain)
        #endif
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlockedAccessibilityDescription)
        .accessibilityHint("Double tap to play level \(levelNumber)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Locked View

    private var lockedView: some View {
        Button {
            showLockedAlert = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "lock.fill")
                    .font(.subheadline)

                Text("\(levelNumber)")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary.opacity(0.5))
            #if os(visionOS)
            .frame(width: 64, height: 64)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .hoverEffect()
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 12, style: .continuous))
            #elseif os(macOS)
            .padding(8)
            .frame(minWidth: 60, minHeight: 60)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            #else
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            #endif
        }
        .buttonStyle(.plain)
        .opacity(0.6)
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(levelNumber), locked")
        .accessibilityHint(lockMessage ?? "Complete more levels in the previous group to unlock")
        .alert("Level Locked", isPresented: $showLockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lockMessage ?? "Complete more levels to unlock this level.")
        }
    }

    // MARK: - Helpers

    private var unlockedAccessibilityDescription: String {
        var description: String
        if starRating > 0 {
            description = "Level \(levelNumber), \(starRating) of 3 stars\(isCurrent ? ", current level" : "")"
        } else {
            description = "Level \(levelNumber)\(isCurrent ? ", current level" : "")"
        }
        return description
    }
}
