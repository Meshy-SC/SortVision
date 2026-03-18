// InAppPurchaseService.swift
// Handles In-App Purchase logic, solution credits, and unlocked solutions tracking.

import Foundation
import StoreKit
import SwiftData
import Combine
import CoreData

// MARK: - InAppPurchaseService

/// Service responsible for managing In-App Purchases and solution credits.
/// Extracted from AppModel to follow single responsibility principle.
/// Uses SwiftData for CloudKit-synced persistence.
@MainActor
@Observable
final class InAppPurchaseService {

    // MARK: - Observable Properties

    /// Current number of solution credits available to the user.
    /// Backed by a stored property; synced from SwiftData at init and on remote changes.
    private(set) var solutionCredits: Int = 0

    /// Updates the solution credits both in SwiftData and the local cached value.
    func setSolutionCredits(_ newValue: Int) {
        let model = updateCreditsModel(to: newValue)
        do {
            try modelContext.save()
        } catch {
            AppLogger.iap.error("Failed to save solution credits: \(error.localizedDescription)")
        }
        solutionCredits = model.credits
        lastLocalCreditModification = Date()
        AppLogger.iap.info("Credits set to \(model.credits) (requested: \(newValue), cap: \(max(0, self.totalLevelsAcrossAllWorlds)))")
    }

    /// Set of world-level keys that have been unlocked for solution viewing.
    /// Mutated only through `consumeSolutionCredit()` and `loadUnlockedSolutions()`.
    private(set) var unlockedSolutions: Set<String> = []

    /// Dynamic maximum for the "Credits" gauge display.
    /// Represents the visual cap for the gauge UI, not the theoretical maximum.
    let maximumSolutionCredits: Int = 10

    /// Total number of levels across all worlds.
    /// This is the absolute maximum number of solution credits that could ever be useful.
    var totalLevelsAcrossAllWorlds: Int {
        World.allWorlds.reduce(0) { $0 + $1.levelCount }
    }

    /// How many more credits the user can acquire before hitting the cap.
    /// Cap = totalLevels − current credit balance.
    var remainingCreditCapacity: Int {
        max(0, totalLevelsAcrossAllWorlds - solutionCredits)
    }

    /// All fetched StoreKit credit products, sorted by credit count.
    private(set) var creditProducts: [Product] = []

    /// Whether the store sheet should be presented.
    var isStoreSheetPresented: Bool = false

    /// Product identifiers for solution credit packages.
    @ObservationIgnored
    private let productIdentifiers: Set<String> = [
        "fr.meshy.pushbox.credits.1",
        "fr.meshy.pushbox.credits.5",
        "fr.meshy.pushbox.credits.10"
    ]

    /// Maps product identifier to the number of credits it grants.
    @ObservationIgnored
    let productCredits: [String: Int] = [
        "fr.meshy.pushbox.credits.1":  1,
        "fr.meshy.pushbox.credits.5":  5,
        "fr.meshy.pushbox.credits.10": 10
    ]
    
    // MARK: - Private Properties
    
    /// Legacy UserDefaults keys for migration.
    private enum LegacyKeys {
        static let unlockedSolutions = "unlockedSolutions"
        static let migrationComplete = "solutionMigrationComplete"
    }
    
    /// SwiftData model context for persistence.
    @ObservationIgnored
    private let modelContext: ModelContext
    
    /// Cached reference to the credits model to avoid repeated fetches within a single session.
    @ObservationIgnored
    private var _cachedCreditsModel: SolutionCreditsModel?
    
    /// Handle for the detached transaction listener task.
    @ObservationIgnored
    private var transactionTask: Task<Void, Never>?
    
    /// Cancellable for CloudKit remote-change notification subscription.
    @ObservationIgnored
    private var remoteChangeCancellable: AnyCancellable?

    /// Timestamp of the last local credit modification.
    /// Used to suppress CloudKit echo notifications that would overwrite a recent local change.
    /// This is the SwiftData equivalent of Apple's Core Data persistent history filter
    /// (`author != "app"`) — since SwiftData doesn't expose transaction authors, we use
    /// a time-based guard to distinguish local echoes from genuine remote changes.
    @ObservationIgnored
    private var lastLocalCreditModification: Date = .distantPast

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Migrate legacy data and load from SwiftData
        migrateFromUserDefaultsIfNeeded()
        loadUnlockedSolutions()
        
        // Sync the stored solutionCredits from SwiftData
        solutionCredits = fetchOrCreateCreditsModel().credits

        // Prefetch product and start transaction listener
        Task { await fetchSolutionProduct() }
        transactionTask = Task.detached { [weak self] in
            await self?.listenForTransactions()
        }
        
        // Listen for CloudKit remote changes to sync credits/unlocked solutions across devices
        remoteChangeCancellable = NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshFromRemoteChanges()
            }
    }
    
    deinit {
        transactionTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Creates a unique key for a world-level combination.
    /// - Parameters:
    ///   - world: The world containing the level.
    ///   - levelIndex: The level index.
    /// - Returns: A string key in format "WorldName-Level".
    func solutionKey(for world: World, levelIndex: Int) -> String {
        "\(world.worldName)-\(levelIndex)"
    }
    
    /// Checks if the solution for a specific level has been unlocked.
    /// - Parameters:
    ///   - world: The world containing the level.
    ///   - level: The level index.
    /// - Returns: `true` if the solution is already unlocked.
    func hasUnlockedSolution(world: World, level: Int) -> Bool {
        unlockedSolutions.contains(solutionKey(for: world, levelIndex: level))
    }
    
    /// Attempts to consume a solution credit for solution playback.
    /// Already-unlocked levels can be replayed without consuming a credit.
    /// - Parameters:
    ///   - world: The world containing the level.
    ///   - level: The level index.
    /// - Returns: `true` if playback can proceed, `false` if no credits available for a new unlock.
    @discardableResult
    func consumeSolutionCredit(for world: World, level: Int) -> Bool {
        let key = solutionKey(for: world, levelIndex: level)

        // Already unlocked: allow free replay without consuming a credit.
        if hasUnlockedSolution(world: world, level: level) {
            AppLogger.iap.info("Level \(key) already unlocked; replaying without consuming credit (credits: \(self.solutionCredits))")
            return true
        }

        // New unlock: require a credit.
        guard solutionCredits > 0 else {
            AppLogger.iap.info("No credits available to unlock solution for \(key) (credits: \(self.solutionCredits))")
            return false
        }

        AppLogger.iap.info("Consuming credit to unlock \(key) (credits before: \(self.solutionCredits))")
        setSolutionCredits(solutionCredits - 1)

        unlockedSolutions.insert(key)

        // Persist to SwiftData (check for existing to avoid duplicates since CloudKit doesn't support unique constraints)
        let existingDescriptor = FetchDescriptor<UnlockedSolutionModel>(predicate: #Predicate { $0.levelKey == key })
        let existingCount = (try? modelContext.fetchCount(existingDescriptor)) ?? 0
        guard existingCount == 0 else {
            AppLogger.iap.info("Unlock record already exists for \(key), skipping insert")
            return true
        }
        let model = UnlockedSolutionModel(levelKey: key)
        modelContext.insert(model)
        do {
            try modelContext.save()
            AppLogger.iap.info("Saved first-time unlock record for \(key) (credits after: \(self.solutionCredits))")
        } catch {
            AppLogger.iap.error("Failed to save unlocked solution for \(key): \(error.localizedDescription)")
        }

        return true
    }
    
    /// Fetches all solution credit products from the App Store.
    func fetchSolutionProduct() async {
        do {
            let products = try await Product.products(for: productIdentifiers)
            // Sort by credit count ascending (1, 5, 10)
            creditProducts = products.sorted {
                (productCredits[$0.id] ?? 0) < (productCredits[$1.id] ?? 0)
            }
        } catch {
            AppLogger.iap.error("Failed to fetch products: \(error.localizedDescription)")
        }
    }
    
    /// Processes the result of a purchase attempt.
    /// Uses explicit case matching per Apple's StoreKit 2 documentation for forward compatibility.
    /// - Parameter result: The purchase result from StoreKit.
    func processPurchaseResult(_ result: Product.PurchaseResult) async throws {
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await grantCreditsAndFinish(transaction)
            case .unverified(let transaction, let error):
                AppLogger.iap.error("Unverified transaction \(transaction.id): \(error.localizedDescription)")
            }
        case .pending:
            break
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Private Methods

    /// Updates the credits model in-place without saving.
    /// Caller is responsible for calling `modelContext.save()` to persist.
    @discardableResult
    private func updateCreditsModel(to newValue: Int) -> SolutionCreditsModel {
        let model = fetchOrCreateCreditsModel()
        let cap = max(0, totalLevelsAcrossAllWorlds)
        model.credits = min(max(0, newValue), cap)
        model.lastModified = Date()
        return model
    }

    /// Grants credits for a verified transaction with idempotency and atomic persistence.
    ///
    /// Follows Apple's WWDC25 SKDemo pattern:
    /// 1. Check if the transaction has already been processed (idempotency guard)
    /// 2. Update credit balance and record the transaction atomically
    /// 3. Only call `finish()` after persistence succeeds
    ///
    /// If persistence fails, the transaction is NOT finished so StoreKit
    /// will redeliver it via `Transaction.updates` on next launch.
    private func grantCreditsAndFinish(_ transaction: Transaction) async {
        guard !hasProcessedTransaction(transaction.id) else {
            AppLogger.iap.info("Transaction \(transaction.id) already processed, finishing")
            await transaction.finish()
            return
        }

        let credits = productCredits[transaction.productID] ?? 0
        guard credits > 0 else {
            AppLogger.iap.warning("Unknown product \(transaction.productID) in transaction \(transaction.id), finishing")
            await transaction.finish()
            return
        }

        let model = updateCreditsModel(to: solutionCredits + credits)

        let record = ProcessedTransactionModel(
            transactionID: transaction.id,
            productID: transaction.productID,
            creditsGranted: credits
        )
        modelContext.insert(record)

        do {
            try modelContext.save()
            solutionCredits = model.credits
            lastLocalCreditModification = Date()
            await transaction.finish()
            AppLogger.iap.info("Granted \(credits) credits for transaction \(transaction.id) (total: \(model.credits))")
        } catch {
            AppLogger.iap.error("Failed to persist transaction \(transaction.id): \(error.localizedDescription)")
        }
    }

    /// Checks whether a transaction has already been processed.
    private func hasProcessedTransaction(_ transactionID: UInt64) -> Bool {
        let idString = String(transactionID)
        let descriptor = FetchDescriptor<ProcessedTransactionModel>(
            predicate: #Predicate { $0.transactionID == idString }
        )
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Loads unlocked solutions from SwiftData.
    private func loadUnlockedSolutions() {
        let descriptor = FetchDescriptor<UnlockedSolutionModel>()
        
        do {
            let models = try modelContext.fetch(descriptor)
            unlockedSolutions = Set(models.map(\.levelKey))
        } catch {
            AppLogger.iap.error("Failed to load unlocked solutions: \(error.localizedDescription)")
        }
    }
    
    /// Migrates legacy UserDefaults data to SwiftData.
    private func migrateFromUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: LegacyKeys.migrationComplete) else { return }
        
        guard let data = UserDefaults.standard.data(forKey: LegacyKeys.unlockedSolutions),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            UserDefaults.standard.set(true, forKey: LegacyKeys.migrationComplete)
            return
        }
        
        for levelKey in array {
            let existingDescriptor = FetchDescriptor<UnlockedSolutionModel>(predicate: #Predicate { $0.levelKey == levelKey })
            let existingCount = (try? modelContext.fetchCount(existingDescriptor)) ?? 0
            guard existingCount == 0 else { continue }
            let model = UnlockedSolutionModel(levelKey: levelKey)
            modelContext.insert(model)
        }
        
        do {
            try modelContext.save()
            UserDefaults.standard.removeObject(forKey: LegacyKeys.unlockedSolutions)
            UserDefaults.standard.set(true, forKey: LegacyKeys.migrationComplete)
            AppLogger.iap.info("Successfully migrated unlocked solutions from UserDefaults to SwiftData")
        } catch {
            AppLogger.iap.error("Failed to migrate unlocked solutions: \(error.localizedDescription)")
        }
    }
    
    /// Fetches the singleton credits model, creating one if it doesn't exist.
    /// Handles duplicate records that can appear after CloudKit sync (since CloudKit
    /// doesn't enforce unique constraints). When duplicates exist, keeps the most
    /// recently modified record and deletes the rest.
    private func fetchOrCreateCreditsModel() -> SolutionCreditsModel {
        if let cached = _cachedCreditsModel { return cached }

        let descriptor = FetchDescriptor<SolutionCreditsModel>()
        let allRecords = (try? modelContext.fetch(descriptor)) ?? []

        if let best = allRecords.max(by: { $0.lastModified < $1.lastModified }) {
            // Delete any duplicates, keeping only the most recently modified record
            if allRecords.count > 1 {
                for record in allRecords where record !== best {
                    AppLogger.iap.info("Deleting stale duplicate credit record (credits: \(record.credits), lastModified: \(record.lastModified))")
                    modelContext.delete(record)
                }
                try? modelContext.save()
                AppLogger.iap.info("Consolidated \(allRecords.count) CloudKit credit records into one (credits: \(best.credits), lastModified: \(best.lastModified))")
            }
            
            _cachedCreditsModel = best
            return best
        }
        
        // First launch or migration: check for old @AppStorage value
        let legacyCredits = UserDefaults.standard.integer(forKey: "solutionCredits")
        let initialCredits = legacyCredits > 0 ? legacyCredits : 1
        
        let model = SolutionCreditsModel(credits: initialCredits)
        modelContext.insert(model)
        try? modelContext.save()
        
        // Clean up old key after migration
        if legacyCredits > 0 {
            UserDefaults.standard.removeObject(forKey: "solutionCredits")
            AppLogger.iap.info("Migrated \(initialCredits) credits from UserDefaults to SwiftData")
        }
        
        _cachedCreditsModel = model
        return model
    }
    
    // MARK: - CloudKit Remote Change Handling
    
    /// Invalidates cached data and re-fetches from SwiftData.
    /// Called when CloudKit pushes changes made on another device.
    ///
    /// Implements a time-based echo guard inspired by Apple's Core Data deduplication pattern.
    /// Apple's sample (`PersistenceController+History.swift`) filters persistent history with
    /// `author != "app"` to ignore local transactions. SwiftData doesn't expose transaction
    /// authors, so we use a time window instead: if credits were modified locally within the
    /// last 3 seconds, this notification is almost certainly an echo of our own save propagating
    /// through the CloudKit mirroring daemon — not a genuine remote change.
    func refreshFromRemoteChanges() {
        // Reload unlocked solutions regardless (these are additive and idempotent)
        loadUnlockedSolutions()

        // Guard against CloudKit echo: skip credit re-fetch if we just modified locally.
        // This prevents the stale duplicate from overwriting our recent decrement.
        let timeSinceLocalChange = Date().timeIntervalSince(lastLocalCreditModification)
        if timeSinceLocalChange < 3.0 {
            AppLogger.iap.info("Skipping credit refresh — local change \(String(format: "%.1f", timeSinceLocalChange))s ago (echo guard)")
            return
        }

        // Genuine remote change: invalidate cache and re-fetch with deduplication.
        _cachedCreditsModel = nil
        let currentCredits = fetchOrCreateCreditsModel().credits
        solutionCredits = currentCredits

        AppLogger.iap.info("Refreshed IAP data after CloudKit remote change — credits: \(currentCredits)")
    }
    
    /// Continuous listener to handle transactions that complete outside explicit purchase flow.
    /// Required by StoreKit per Apple's documentation: "Create a task to iterate through the
    /// transactions from the listener as soon as your app launches."
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await grantCreditsAndFinish(transaction)
        }
    }
}
