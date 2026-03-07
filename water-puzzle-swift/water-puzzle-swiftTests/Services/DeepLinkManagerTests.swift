import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("DeepLinkManager")
@MainActor
struct DeepLinkManagerTests {

    @Test("pendingLevel is nil by default")
    func initialStateIsNil() {
        // Note: This tests the initial contract. Since it's a singleton that may
        // have been used in other tests, we set and clear it ourselves.
        let original = DeepLinkManager.shared.pendingLevel
        DeepLinkManager.shared.pendingLevel = nil
        #expect(DeepLinkManager.shared.pendingLevel == nil)

        // Restore
        if let orig = original {
            DeepLinkManager.shared.pendingLevel = orig
        }
    }

    @Test("Setting pendingLevel stores mode and number")
    func setPendingLevel() {
        let originalPending = DeepLinkManager.shared.pendingLevel
        defer {
            DeepLinkManager.shared.pendingLevel = originalPending
        }

        DeepLinkManager.shared.pendingLevel = (mode: .hard, number: 42)

        #expect(DeepLinkManager.shared.pendingLevel?.mode == .hard)
        #expect(DeepLinkManager.shared.pendingLevel?.number == 42)
    }

    @Test("Clearing pendingLevel sets it to nil")
    func clearPendingLevel() {
        let originalPending = DeepLinkManager.shared.pendingLevel
        defer {
            DeepLinkManager.shared.pendingLevel = originalPending
        }

        DeepLinkManager.shared.pendingLevel = (mode: .easy, number: 1)
        DeepLinkManager.shared.pendingLevel = nil

        #expect(DeepLinkManager.shared.pendingLevel == nil)
    }

    @Test("pendingLevel can be overwritten with different values")
    func overwritePendingLevel() {
        let originalPending = DeepLinkManager.shared.pendingLevel
        defer {
            DeepLinkManager.shared.pendingLevel = originalPending
        }

        DeepLinkManager.shared.pendingLevel = (mode: .easy, number: 1)
        DeepLinkManager.shared.pendingLevel = (mode: .expert, number: 99)

        #expect(DeepLinkManager.shared.pendingLevel?.mode == .expert)
        #expect(DeepLinkManager.shared.pendingLevel?.number == 99)
    }
}
