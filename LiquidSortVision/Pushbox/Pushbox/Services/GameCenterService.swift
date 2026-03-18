// GameCenterService.swift
// Manages Game Center authentication, leaderboard score submission, achievements, and challenges.

import Foundation
import GameKit

// MARK: - GameCenterService

/// Service responsible for Game Center integration.
/// Handles player authentication, score submission to leaderboards,
/// achievement reporting, and challenge support.
///
/// Uses Apple's recommended GameKit APIs:
/// - `GKLocalPlayer` for authentication
/// - `GKLeaderboard.submitScore` for score submission
/// - `GKAchievement` for achievement progress reporting
/// - `GKAccessPoint` for challenge UI
@MainActor
@Observable
final class GameCenterService {

    // MARK: - Leaderboard IDs

    /// Leaderboard identifier for the overall global score.
    /// Must match the leaderboard ID configured in App Store Connect.
    static let globalScoreLeaderboardID = "fr.meshy.pushbox.globalscore"

    /// Per-world leaderboard identifiers for challenge support.
    /// Each world has its own leaderboard tracking the player's world score.
    /// Must match the leaderboard IDs configured in App Store Connect.
    static let worldLeaderboardIDs: [String: String] = [
        "World1": "fr.meshy.pushbox.world1score",
        "World2": "fr.meshy.pushbox.world2score",
        "World3": "fr.meshy.pushbox.world3score",
        "World4": "fr.meshy.pushbox.world4score",
        "World5": "fr.meshy.pushbox.world5score",
        "World6": "fr.meshy.pushbox.world6score",
        "World7": "fr.meshy.pushbox.world7score",
        "World8": "fr.meshy.pushbox.world8score",
        "World9": "fr.meshy.pushbox.world9score",
        "World10": "fr.meshy.pushbox.world10score"
    ]

    // MARK: - Achievement IDs

    /// Achievement identifiers grouped by category.
    /// Designed to be future-proof: no per-world IDs, uses generic milestone counting
    /// so new worlds can be added without changing achievements.
    /// Must match the achievement IDs configured in App Store Connect.
    enum AchievementID {
        // --- Level completion milestones ---
        static let firstSteps           = "fr.meshy.pushbox.first_steps"
        static let tenDown              = "fr.meshy.pushbox.ten_down"
        static let fiftySolver          = "fr.meshy.pushbox.fifty_solver"
        static let century              = "fr.meshy.pushbox.century"
        static let doubleCentury        = "fr.meshy.pushbox.double_century"
        static let completionist        = "fr.meshy.pushbox.completionist"

        // --- World exploration milestones (generic, scales with new worlds) ---
        static let worldConqueror       = "fr.meshy.pushbox.world_conqueror"
        static let dualExplorer         = "fr.meshy.pushbox.dual_explorer"
        static let globeTrotter         = "fr.meshy.pushbox.globe_trotter"

        // --- Star milestones ---
        static let starCollector        = "fr.meshy.pushbox.star_collector"
        static let starHoarder          = "fr.meshy.pushbox.star_hoarder"
        static let shiningBright        = "fr.meshy.pushbox.shining_bright"
        static let perfectionist        = "fr.meshy.pushbox.perfectionist"

        // --- Mastery milestones (generic, scales with new worlds) ---
        static let worldMaster          = "fr.meshy.pushbox.world_master"
        static let tripleMaster         = "fr.meshy.pushbox.triple_master"
        static let absoluteMaster       = "fr.meshy.pushbox.absolute_master"

        // --- Optimal solve skill achievements ---
        static let optimalSolver        = "fr.meshy.pushbox.optimal_solver"
        static let precisionExpert      = "fr.meshy.pushbox.precision_expert"
        static let hiddenTalent         = "fr.meshy.pushbox.hidden_talent"

        // --- Grand master: maximum possible score ---
        static let grandMaster          = "fr.meshy.pushbox.grand_master"
    }

    // MARK: - Observable Properties

    /// Whether the local player is authenticated with Game Center.
    var isAuthenticated = false

    // MARK: - Initialization

    nonisolated init() {
        Task { @MainActor in
            self.authenticatePlayer()
        }
    }

    // MARK: - Authentication

    /// Authenticates the local player with Game Center.
    ///
    /// Sets the `authenticateHandler` on `GKLocalPlayer.local`, which
    /// triggers the Game Center sign-in flow if the player isn't already
    /// signed in. On success, updates `isAuthenticated`.
    func authenticatePlayer() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    AppLogger.gameCenter.error("Game Center authentication failed: \(error.localizedDescription)")
                    self.isAuthenticated = false
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated {
                    AppLogger.gameCenter.info("Game Center authenticated as \(GKLocalPlayer.local.displayName)")
                }
            }
        }
    }

    // MARK: - Score Submission

    /// Submits the player's global score to the Game Center leaderboard.
    ///
    /// The global score is calculated from star ratings across all worlds:
    /// - 3 stars = 10 points
    /// - 2 stars = 7 points
    /// - 1 star = 5 points
    ///
    /// - Parameter score: The total global score to submit.
    func submitScore(_ score: Int) {
        guard isAuthenticated else {
            AppLogger.gameCenter.debug("Skipping score submission — not authenticated")
            return
        }

        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [Self.globalScoreLeaderboardID]
                )
                AppLogger.gameCenter.info("Submitted global score \(score) to Game Center")
            } catch {
                AppLogger.gameCenter.error("Failed to submit global score: \(error.localizedDescription)")
            }
        }
    }

    /// Submits the player's world-specific score to the per-world leaderboard.
    ///
    /// Used for challenge support — each world has its own leaderboard so players
    /// can challenge friends to beat their score in a specific world.
    ///
    /// - Parameters:
    ///   - score: The total score for this world.
    ///   - worldName: The world identifier (e.g., "World1").
    func submitWorldScore(_ score: Int, worldName: String) {
        guard isAuthenticated else {
            AppLogger.gameCenter.debug("Skipping world score submission — not authenticated")
            return
        }
        guard let leaderboardID = Self.worldLeaderboardIDs[worldName] else {
            AppLogger.gameCenter.error("No leaderboard ID for world: \(worldName)")
            return
        }

        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
                AppLogger.gameCenter.info("Submitted world score \(score) for \(worldName)")
            } catch {
                AppLogger.gameCenter.error("Failed to submit world score for \(worldName): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Achievement Reporting

    /// Reports progress toward a single achievement.
    ///
    /// GameKit automatically ignores reports where the new percentage is lower
    /// than the previously reported percentage. Safe to call repeatedly.
    ///
    /// - Parameters:
    ///   - achievementID: The achievement identifier from App Store Connect.
    ///   - percentComplete: Progress from 0.0 to 100.0. At 100.0, the achievement is earned.
    private func reportAchievement(_ achievementID: String, percentComplete: Double) {
        guard isAuthenticated else { return }

        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true

        Task {
            do {
                try await GKAchievement.report([achievement])
                if percentComplete >= 100.0 {
                    AppLogger.gameCenter.info("Achievement unlocked: \(achievementID)")
                } else {
                    AppLogger.gameCenter.debug("Achievement progress \(achievementID): \(percentComplete)%")
                }
            } catch {
                AppLogger.gameCenter.error("Failed to report achievement \(achievementID): \(error.localizedDescription)")
            }
        }
    }

    /// Evaluates all achievements based on current progress and reports updates.
    ///
    /// Called after every level completion. GameKit deduplicates, so calling this
    /// with the same percentages multiple times has no adverse effect.
    ///
    /// Achievement design is future-proof: uses generic world-counting milestones
    /// rather than per-world IDs, so new worlds can be added without changes.
    ///
    /// - Parameter progress: The full progress dictionary from ProgressService.
    func checkAndReportAchievements(progress: [String: [Int: LevelProgress]]) {
        guard isAuthenticated else { return }

        let allWorlds = World.allWorlds
        let totalLevelsInGame = allWorlds.reduce(0) { $0 + $1.levelCount }
        let allCompleted = progress.values.flatMap(\.values).filter(\.isCompleted)
        let totalCompleted = allCompleted.count
        let totalStars = allCompleted.reduce(0) { $0 + $1.starRating }
        let totalThreeStars = allCompleted.filter { $0.starRating == 3 }.count

        // --- Per-world completion and mastery counts (generic, scales with new worlds) ---
        var worldsFullyCompleted = 0
        var worldsFullyMastered = 0
        for world in allWorlds {
            let worldCompleted = progress[world.worldName]?.values.filter(\.isCompleted).count ?? 0
            let worldThreeStars = progress[world.worldName]?.values.filter { $0.starRating == 3 }.count ?? 0
            if worldCompleted >= world.levelCount {
                worldsFullyCompleted += 1
            }
            if worldThreeStars >= world.levelCount {
                worldsFullyMastered += 1
            }
        }

        let totalWorlds = allWorlds.count
        let maxStars = totalLevelsInGame * 3
        let maxScore = totalLevelsInGame * 10

        // --- First Steps (1 level) ---
        if totalCompleted >= 1 {
            reportAchievement(AchievementID.firstSteps, percentComplete: 100)
        }

        // --- Level Completion Milestones ---
        reportAchievement(AchievementID.tenDown,        percentComplete: min(100, Double(totalCompleted) / 10.0 * 100))
        reportAchievement(AchievementID.fiftySolver,    percentComplete: min(100, Double(totalCompleted) / 50.0 * 100))
        reportAchievement(AchievementID.century,        percentComplete: min(100, Double(totalCompleted) / 100.0 * 100))
        reportAchievement(AchievementID.doubleCentury,  percentComplete: min(100, Double(totalCompleted) / 200.0 * 100))
        reportAchievement(AchievementID.completionist,  percentComplete: min(100, Double(totalCompleted) / Double(totalLevelsInGame) * 100))

        // --- World Exploration Milestones (generic) ---
        if worldsFullyCompleted >= 1 {
            reportAchievement(AchievementID.worldConqueror, percentComplete: 100)
        }
        if worldsFullyCompleted >= 2 {
            reportAchievement(AchievementID.dualExplorer, percentComplete: 100)
        }
        reportAchievement(AchievementID.globeTrotter,   percentComplete: min(100, Double(worldsFullyCompleted) / Double(totalWorlds) * 100))

        // --- Star Milestones ---
        reportAchievement(AchievementID.starCollector,  percentComplete: min(100, Double(totalStars) / 100.0 * 100))
        reportAchievement(AchievementID.starHoarder,    percentComplete: min(100, Double(totalStars) / 500.0 * 100))
        reportAchievement(AchievementID.shiningBright,  percentComplete: min(100, Double(totalStars) / 1000.0 * 100))
        reportAchievement(AchievementID.perfectionist,  percentComplete: min(100, Double(totalStars) / Double(maxStars) * 100))

        // --- Mastery Milestones (generic) ---
        if worldsFullyMastered >= 1 {
            reportAchievement(AchievementID.worldMaster, percentComplete: 100)
        }
        if worldsFullyMastered >= 3 {
            reportAchievement(AchievementID.tripleMaster, percentComplete: 100)
        }
        reportAchievement(AchievementID.absoluteMaster, percentComplete: min(100, Double(worldsFullyMastered) / Double(totalWorlds) * 100))

        // --- Optimal Solve Skill Achievements ---
        if totalThreeStars >= 1 {
            reportAchievement(AchievementID.optimalSolver, percentComplete: 100)
        }
        reportAchievement(AchievementID.precisionExpert, percentComplete: min(100, Double(totalThreeStars) / 5.0 * 100))
        reportAchievement(AchievementID.hiddenTalent,   percentComplete: min(100, Double(totalThreeStars) / 25.0 * 100))

        // --- Grand Master (max score = totalLevels × 10) ---
        let globalScore = allCompleted.reduce(0) { score, lp in
            switch lp.starRating {
            case 3: return score + 10
            case 2: return score + 7
            default: return score + 5
            }
        }
        reportAchievement(AchievementID.grandMaster,    percentComplete: min(100, Double(globalScore) / Double(maxScore) * 100))
    }

    // MARK: - World Score Calculation

    /// Calculates the score for a single world from progress data.
    ///
    /// Scoring: 3 stars = 10 pts, 2 stars = 7 pts, 1 star = 5 pts.
    ///
    /// - Parameters:
    ///   - worldName: The world identifier.
    ///   - progress: The full progress dictionary.
    /// - Returns: The total score for the specified world.
    static func worldScore(for worldName: String, from progress: [String: [Int: LevelProgress]]) -> Int {
        guard let worldProgress = progress[worldName] else { return 0 }
        return worldProgress.values.filter(\.isCompleted).reduce(0) { score, lp in
            switch lp.starRating {
            case 3: return score + 10
            case 2: return score + 7
            default: return score + 5
            }
        }
    }

    // MARK: - Challenges UI

    /// Presents the Game Center challenge UI for inviting friends.
    ///
    /// On iOS 26+ this uses the dedicated "Play Together" flow.
    /// On earlier versions and visionOS, it opens the Game Center dashboard
    /// where players can initiate challenges from within the leaderboard view.
    func presentChallenges() {
        guard isAuthenticated else {
            AppLogger.gameCenter.debug("Cannot present challenges — not authenticated")
            return
        }
        Task {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                await GKAccessPoint.shared.triggerForPlayTogether()
            } else {
                GKAccessPoint.shared.trigger(state: .leaderboards) { }
            }
            #else
            // visionOS / macOS — open the Game Center dashboard to the leaderboards
            GKAccessPoint.shared.trigger(state: .leaderboards) { }
            #endif
        }
    }
}
