import SwiftUI

/// A card representing a world in the world selection screen.
///
/// Displays the world icon, name, subtitle, circular progress gauge,
/// and completion count. Supports three states:
/// - **Accessible**: Full-color card with progress, tappable
/// - **Locked**: Dimmed card with lock icon, not tappable
/// - **Coming Soon**: Dimmed card with "Coming Soon" label
struct WorldCardView: View {
    let stage: Stage
    let completed: Int
    let total: Int
    let isAccessible: Bool
    let isComingSoon: Bool

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack(spacing: 16) {
            // World icon
            worldIcon

            // World info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("World \(stage.worldNumber)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isAccessible ? stage.themeColor : .secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    if isComingSoon {
                        Text("Coming Soon")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.secondary.opacity(0.3))
                            )
                    }
                }

                Text(stage.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isAccessible ? .primary : .secondary)

                Text(stage.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(isAccessible ? .secondary : .tertiary)
            }

            Spacer()

            // Right side: gauge or lock
            if isComingSoon {
                Image(systemName: "clock")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            } else if !isAccessible {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            } else {
                CircularStatGauge(
                    value: completed,
                    maxValue: total,
                    title: "",
                    tintColor: stage.themeColor
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isAccessible
                                ? stage.themeColor.opacity(0.08)
                                : Color.clear
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isAccessible
                                ? stage.themeColor.opacity(0.2)
                                : Color.secondary.opacity(0.1),
                            lineWidth: 1
                        )
                }
        }
        .opacity(isAccessible ? 1.0 : (isComingSoon ? 0.5 : 0.7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(isAccessible ? "Double tap to view levels" : "")
    }

    // MARK: - Subviews

    private var worldIcon: some View {
        ZStack {
            Circle()
                .fill(
                    isAccessible
                        ? LinearGradient(
                            colors: [stage.themeColor, stage.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [.secondary.opacity(0.3), .secondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 48, height: 48)

            Image(systemName: stage.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var accessibilityLabelText: String {
        if isComingSoon {
            return "World \(stage.worldNumber), \(stage.displayName), \(stage.subtitle), coming soon"
        }
        if !isAccessible {
            return "World \(stage.worldNumber), \(stage.displayName), \(stage.subtitle), locked"
        }
        return "World \(stage.worldNumber), \(stage.displayName), \(stage.subtitle), \(completed) of \(total) completed"
    }
}
