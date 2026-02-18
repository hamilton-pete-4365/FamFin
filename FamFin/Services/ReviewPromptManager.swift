import SwiftUI
import StoreKit

/// Events that represent meaningful user milestones worthy of triggering
/// an App Store review prompt.
enum ReviewEvent {
    case budgetMonthCompleted
    case goalMilestoneReached
    case recurringTransactionCreated
}

/// Manages App Store review prompts by tracking meaningful user events
/// and prompting at optimal moments. Uses the SwiftUI `requestReview`
/// environment action instead of the deprecated `SKStoreReviewController`.
///
/// Prompt conditions (all must be true):
/// - At least 5 app sessions
/// - At least 7 days since install
/// - A meaningful event just occurred
/// - At least 60 days since the last prompt
@MainActor @Observable
final class ReviewPromptManager {

    // MARK: - Storage Keys

    private enum StorageKey {
        static let sessionCount = "reviewPrompt_sessionCount"
        static let installDate = "reviewPrompt_installDate"
        static let lastPromptDate = "reviewPrompt_lastPromptDate"
        static let budgetMonthCompleted = "reviewPrompt_budgetMonthCompleted"
        static let goalMilestoneReached = "reviewPrompt_goalMilestoneReached"
    }

    // MARK: - Thresholds

    /// Minimum number of app sessions before prompting.
    private static let minimumSessions = 5

    /// Minimum days since install before prompting.
    private static let minimumDaysSinceInstall = 7

    /// Minimum days between successive prompts.
    private static let daysBetweenPrompts = 60

    // MARK: - Tracked State

    /// Number of times the app has been opened.
    private(set) var sessionCount: Int {
        didSet { UserDefaults.standard.set(sessionCount, forKey: StorageKey.sessionCount) }
    }

    /// The date the app was first launched (for review-prompt purposes).
    private let installDate: Date

    /// The date of the last review prompt, if any.
    private var lastPromptDate: Date? {
        didSet { UserDefaults.standard.set(lastPromptDate, forKey: StorageKey.lastPromptDate) }
    }

    /// Whether the user has completed at least one budget month.
    private var hasBudgetMonthCompleted: Bool {
        didSet { UserDefaults.standard.set(hasBudgetMonthCompleted, forKey: StorageKey.budgetMonthCompleted) }
    }

    /// Whether the user has reached at least one savings goal milestone (25%+).
    private var hasGoalMilestoneReached: Bool {
        didSet { UserDefaults.standard.set(hasGoalMilestoneReached, forKey: StorageKey.goalMilestoneReached) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        sessionCount = defaults.integer(forKey: StorageKey.sessionCount)
        hasBudgetMonthCompleted = defaults.bool(forKey: StorageKey.budgetMonthCompleted)
        hasGoalMilestoneReached = defaults.bool(forKey: StorageKey.goalMilestoneReached)
        lastPromptDate = defaults.object(forKey: StorageKey.lastPromptDate) as? Date

        // Resolve or record the install date for review prompts.
        if let stored = defaults.object(forKey: StorageKey.installDate) as? Date {
            installDate = stored
        } else {
            let now = Date.now
            defaults.set(now, forKey: StorageKey.installDate)
            installDate = now
        }
    }

    // MARK: - Session Tracking

    /// Call once per app launch (in `onAppear` of the root view) to increment
    /// the session counter.
    func incrementSessionCount() {
        sessionCount += 1
    }

    // MARK: - Event Recording

    /// Records a meaningful user event and requests a review if conditions are met.
    ///
    /// - Parameters:
    ///   - event: The event that just occurred.
    ///   - requestReview: The SwiftUI `requestReview` environment action.
    func recordEvent(_ event: ReviewEvent, requestReview: RequestReviewAction) {
        switch event {
        case .budgetMonthCompleted:
            hasBudgetMonthCompleted = true
        case .goalMilestoneReached:
            hasGoalMilestoneReached = true
        case .recurringTransactionCreated:
            break // No persistent flag needed; the event itself is the trigger.
        }

        if shouldPrompt {
            lastPromptDate = .now
            requestReview()
        }
    }

    // MARK: - Prompt Logic

    /// Whether all conditions for requesting a review are currently satisfied.
    private var shouldPrompt: Bool {
        guard sessionCount >= Self.minimumSessions else { return false }

        let daysSinceInstall = Calendar.current.dateComponents(
            [.day], from: installDate, to: .now
        ).day ?? 0
        guard daysSinceInstall >= Self.minimumDaysSinceInstall else { return false }

        if let lastPrompt = lastPromptDate {
            let daysSinceLastPrompt = Calendar.current.dateComponents(
                [.day], from: lastPrompt, to: .now
            ).day ?? 0
            guard daysSinceLastPrompt >= Self.daysBetweenPrompts else { return false }
        }

        return true
    }
}
