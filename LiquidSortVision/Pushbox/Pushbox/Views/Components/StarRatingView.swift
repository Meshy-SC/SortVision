// StarRatingView.swift
// Reusable star rating display component.

import SwiftUI

// MARK: - StarRatingView

/// A reusable view that displays a star rating.
/// Shows filled or empty stars based on the current rating value.
struct StarRatingView: View {
    
    // MARK: - Properties
    
    /// The current star rating (0 to maxStars).
    let rating: Int
    
    /// Maximum number of stars to display.
    var maxStars: Int = 3
    
    /// Color for filled stars.
    var filledColor: Color = .yellow
    
    /// Color for empty stars.
    /// Uses `.tertiary` (a semantic, vibrancy-aware foreground style) so the
    /// empty stars adapt correctly to visionOS glass materials and other
    /// platform contexts per Apple HIG materials guidance.
    var emptyColor: Color = .secondary.opacity(0.4)
    
    /// Font for the star icons.
    var font: Font = .caption
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxStars, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(font)
                    .foregroundStyle(index < rating ? filledColor : emptyColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rating) of \(maxStars) stars")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StarRatingView(rating: 0)
        StarRatingView(rating: 1)
        StarRatingView(rating: 2)
        StarRatingView(rating: 3)
        StarRatingView(rating: 2, maxStars: 5, filledColor: .yellow)
    }
    .padding()
}
