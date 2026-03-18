// PushCountGaugeOrnament.swift
#if os(visionOS)
// Ornament displaying the push count gauge relative to optimal.

import SwiftUI

/// Ornament displaying a circular gauge of the current push count
/// relative to the two-star threshold for the active level.
struct PushCountGaugeOrnament: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        if let optimalPushes = appModel.optimalPushes, optimalPushes > 0 {
            let currentPushes = Double(appModel.progressService.currentLevelPushes)
            let optimal = Double(optimalPushes)
            let twoStarThreshold = ceil(optimal * 1.2)
            let tintColor: Color = if currentPushes <= optimal {
                .green
            } else if currentPushes <= twoStarThreshold {
                .orange
            } else {
                .red
            }

            CircularStatGauge(title: "Pushes", value: currentPushes, maxValue: twoStarThreshold, tintColor: tintColor)
                .padding()
                .glassBackgroundEffect()
                .accessibilityLabel("Pushes: \(Int(currentPushes)) out of \(Int(twoStarThreshold))")
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
    }
}

#Preview {
    PushCountGaugeOrnament()
        .environment(AppModel.preview)
}
#endif
