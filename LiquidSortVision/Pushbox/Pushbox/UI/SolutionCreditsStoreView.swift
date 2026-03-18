// SolutionCreditsStoreView.swift
// Cross-platform sheet for purchasing solution credit packages.
// Uses StoreKit's built-in StoreView for product display and purchase handling.

import SwiftUI
import StoreKit

// MARK: - SolutionCreditsStoreView

/// A sheet view presenting solution credit packages for purchase.
/// Uses Apple's `StoreView` for automatic price localization, accessibility,
/// and purchase flow — replacing the previous custom product listing UI.
struct SolutionCreditsStoreView: View {

    // MARK: - Environment

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants

    /// Product identifiers for solution credit packages, ordered by credit count.
    private let productIdentifiers = [
        "fr.meshy.pushbox.credits.1",
        "fr.meshy.pushbox.credits.5",
        "fr.meshy.pushbox.credits.10"
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    // Apple's built-in store UI handles product display,
                    // pricing, purchase flow, and error handling.
                    StoreView(ids: productIdentifiers)
                        #if os(iOS) || os(macOS) || os(tvOS)
                        .productViewStyle(.compact)
                        #endif
                        #if !os(tvOS)
                        .storeButton(.hidden, for: .cancellation)
                        #endif
                        .onInAppPurchaseCompletion { product, result in
                            await handlePurchaseCompletion(product: product, result: result)
                        }
                }
                .padding()
                #if os(visionOS)
                .frame(minWidth: 380, idealWidth: 420, maxWidth: 500)
                #endif
            }
            .navigationTitle("Solution Credits")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS) || os(macOS) || os(tvOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif

        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
                .symbolEffect(.pulse.byLayer, options: .repeat(2))

            Text("Get Solution Credits")
                .font(.title2.weight(.bold))

            HStack(spacing: 4) {
                Text("You have")
                    .foregroundStyle(.secondary)
                Text("\(appModel.inAppPurchaseService.solutionCredits)")
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                Text(appModel.inAppPurchaseService.solutionCredits == 1 ? "credit" : "credits")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Text("Use credits to play level solutions.\nEach playback consumes one credit.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if appModel.inAppPurchaseService.remainingCreditCapacity == 0 {
                Label("You have enough credits to cover every remaining level.", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Purchase Handling

    /// Processes the result of a StoreView purchase completion.
    private func handlePurchaseCompletion(product: Product, result: Result<Product.PurchaseResult, any Error>) async {
        switch result {
        case .success(let purchaseResult):
            do {
                try await appModel.inAppPurchaseService.processPurchaseResult(purchaseResult)
            } catch {
                AppLogger.iap.error("Purchase processing failed: \(error.localizedDescription)")
            }
        case .failure(let error):
            AppLogger.iap.error("Purchase failed: \(error.localizedDescription)")
        }
    }
}
