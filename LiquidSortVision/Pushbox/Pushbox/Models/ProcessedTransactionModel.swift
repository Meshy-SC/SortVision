// ProcessedTransactionModel.swift
// SwiftData model for tracking processed consumable transactions with CloudKit sync.

import Foundation
import SwiftData

// MARK: - ProcessedTransactionModel

/// SwiftData model for recording which StoreKit transactions have been processed.
/// Prevents double-granting credits if the app crashes between granting and finishing a transaction,
/// or if an unfinished transaction is redelivered via `Transaction.updates` on next launch.
///
/// This follows Apple's WWDC25 SKDemo pattern where consumable purchase entitlements
/// are persisted using SwiftData to ensure idempotent transaction processing.
///
/// Indexed on `transactionID` for efficient duplicate lookups during purchase processing.
@Model
final class ProcessedTransactionModel {

    #Index<ProcessedTransactionModel>([\.transactionID])

    /// StoreKit transaction identifier, stored as String for CloudKit compatibility.
    /// Default value required for CloudKit compatibility.
    var transactionID: String = ""

    /// Product identifier from the transaction.
    /// Default value required for CloudKit compatibility.
    var productID: String = ""

    /// Number of credits granted for this transaction.
    /// Default value required for CloudKit compatibility.
    var creditsGranted: Int = 0

    /// Timestamp when the transaction was processed.
    /// Default value required for CloudKit compatibility.
    var processedAt: Date = Date()

    // MARK: - Initialization

    init(transactionID: UInt64, productID: String, creditsGranted: Int) {
        self.transactionID = String(transactionID)
        self.productID = productID
        self.creditsGranted = creditsGranted
        self.processedAt = Date()
    }
}
