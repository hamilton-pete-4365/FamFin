import Foundation
import SwiftData

/// Records a user action within a shared family budget for the activity feed.
/// Each entry captures what happened, who did it, and when.
@Model
final class ActivityEntry {
    var message: String = ""
    var timestamp: Date = Date()
    var participantName: String = ""
    var activityType: ActivityType = ActivityType.addedTransaction

    init(
        message: String,
        participantName: String,
        activityType: ActivityType,
        timestamp: Date = Date()
    ) {
        self.message = message
        self.participantName = participantName
        self.activityType = activityType
        self.timestamp = timestamp
    }
}

/// The kind of action that generated an activity feed entry.
enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case addedTransaction = "Added Transaction"
    case editedTransaction = "Edited Transaction"
    case deletedTransaction = "Deleted Transaction"
    case editedBudget = "Edited Budget"
    case addedGoalContribution = "Added Goal Contribution"
    case createdGoal = "Created Goal"
    case joinedFamily = "Joined Family"
    case leftFamily = "Left Family"

    var id: String { rawValue }

    /// SF Symbol name for this activity type.
    var systemImage: String {
        switch self {
        case .addedTransaction: return "plus.circle.fill"
        case .editedTransaction: return "pencil.circle.fill"
        case .deletedTransaction: return "trash.circle.fill"
        case .editedBudget: return "chart.pie.fill"
        case .addedGoalContribution: return "target"
        case .createdGoal: return "star.circle.fill"
        case .joinedFamily: return "person.badge.plus"
        case .leftFamily: return "person.badge.minus"
        }
    }

    /// Tint colour name for each activity type.
    var tintColor: String {
        switch self {
        case .addedTransaction: return "green"
        case .editedTransaction: return "blue"
        case .deletedTransaction: return "red"
        case .editedBudget: return "orange"
        case .addedGoalContribution: return "purple"
        case .createdGoal: return "yellow"
        case .joinedFamily: return "green"
        case .leftFamily: return "red"
        }
    }
}
