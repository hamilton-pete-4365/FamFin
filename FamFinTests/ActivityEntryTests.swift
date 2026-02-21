import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - ActivityEntry Tests

@Suite("ActivityEntry model")
struct ActivityEntryTests {

    @MainActor @Test("Creates entry with all fields")
    func createsWithAllFields() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let entry = ActivityEntry(
            message: "Added grocery transaction",
            participantName: "Alice",
            activityType: .addedTransaction
        )
        context.insert(entry)
        try context.save()

        #expect(entry.message == "Added grocery transaction")
        #expect(entry.participantName == "Alice")
        #expect(entry.activityType == .addedTransaction)
    }

    @MainActor @Test("Default property values for CloudKit compatibility")
    func defaultPropertyValues() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let entry = ActivityEntry(
            message: "Test",
            participantName: "Bob",
            activityType: .editedBudget
        )
        context.insert(entry)
        try context.save()

        #expect(!entry.message.isEmpty)
        #expect(!entry.participantName.isEmpty)
    }

    @MainActor @Test("Custom timestamp is preserved")
    func customTimestamp() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let specificDate = makeDate(year: 2025, month: 3, day: 15)
        let entry = ActivityEntry(
            message: "Past event",
            participantName: "Charlie",
            activityType: .editedBudget,
            timestamp: specificDate
        )
        context.insert(entry)
        try context.save()

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
        #expect(comps.year == 2025)
        #expect(comps.month == 3)
        #expect(comps.day == 15)
    }
}

// MARK: - ActivityType Tests

@Suite("ActivityType properties")
struct ActivityTypeTests {

    @Test("All cases have system images")
    func allCasesHaveImages() {
        for type in ActivityType.allCases {
            #expect(!type.systemImage.isEmpty, "\(type.rawValue) should have a system image")
        }
    }

    @Test("All cases have tint colors")
    func allCasesHaveTintColors() {
        for type in ActivityType.allCases {
            #expect(!type.tintColor.isEmpty, "\(type.rawValue) should have a tint color")
        }
    }

    @Test("All cases are iterable")
    func allCases() {
        #expect(ActivityType.allCases.count == 6)
    }

    @Test("Raw values are human-readable")
    func rawValues() {
        #expect(ActivityType.addedTransaction.rawValue == "Added Transaction")
        #expect(ActivityType.editedBudget.rawValue == "Edited Budget")
        #expect(ActivityType.joinedFamily.rawValue == "Joined Family")
    }
}
