import Foundation
import Testing

@testable import SortVision

@Suite("DeepLinkManager")
@MainActor
struct DeepLinkManagerTests {

    @Test("pendingLevel is nil by default")
    func initialStateIsNil() {
        let original = DeepLinkManager.shared.pendingLevel
        DeepLinkManager.shared.pendingLevel = nil
        #expect(DeepLinkManager.shared.pendingLevel == nil)

        // Restore
        if let orig = original {
            DeepLinkManager.shared.pendingLevel = orig
        }
    }

    @Test("Setting pendingLevel stores global level number")
    func setPendingLevel() {
        let originalPending = DeepLinkManager.shared.pendingLevel
        defer {
            DeepLinkManager.shared.pendingLevel = originalPending
        }

        DeepLinkManager.shared.pendingLevel = 42

        #expect(DeepLinkManager.shared.pendingLevel == 42)
    }

    @Test("Clearing pendingLevel sets it to nil")
    func clearPendingLevel() {
        let originalPending = DeepLinkManager.shared.pendingLevel
        defer {
            DeepLinkManager.shared.pendingLevel = originalPending
        }

        DeepLinkManager.shared.pendingLevel = 1
        DeepLinkManager.shared.pendingLevel = nil

        #expect(DeepLinkManager.shared.pendingLevel == nil)
    }

    @Test("pendingLevel can be overwritten with different values")
    func overwritePendingLevel() {
        let originalPending = DeepLinkManager.shared.pendingLevel
        defer {
            DeepLinkManager.shared.pendingLevel = originalPending
        }

        DeepLinkManager.shared.pendingLevel = 1
        DeepLinkManager.shared.pendingLevel = 99

        #expect(DeepLinkManager.shared.pendingLevel == 99)
    }
}
