import Foundation
import SwiftData
import Testing
@testable import FamFin

// MARK: - SavingsGoal Tests

@Suite("SavingsGoal model")
struct SavingsGoalTests {

    /// Helper: create a goal linked to a category with a given budget allocation
    @MainActor
    private func makeGoalWithBudget(
        targetAmount: Decimal,
        budgetedAmount: Decimal,
        targetDate: Date? = nil,
        month: Date? = nil
    ) throws -> (ModelContainer, SavingsGoal, BudgetCategory, Date) {
        let container = try makeTestContainer()
        let context = container.mainContext

        let budgetMonth = month ?? startOfMonth(Date())

        let category = BudgetCategory(name: "Savings", emoji: "💰")
        context.insert(category)

        let goal = SavingsGoal(name: "Test Goal", targetAmount: targetAmount, targetDate: targetDate)
        goal.linkedCategory = category
        context.insert(goal)

        if budgetedAmount != .zero {
            let bm = BudgetMonth(month: budgetMonth)
            context.insert(bm)
            let allocation = BudgetAllocation(budgeted: budgetedAmount)
            allocation.category = category
            allocation.budgetMonth = bm
            context.insert(allocation)
        }

        try context.save()
        return (container, goal, category, budgetMonth)
    }

    @MainActor @Test("Progress is zero when nothing budgeted")
    func zeroProgress() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 10000, budgetedAmount: .zero)
        #expect(goal.progress(through: month) == 0)
    }

    @MainActor @Test("Progress is correct for partial savings")
    func partialProgress() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 2000, budgetedAmount: 500)
        #expect(goal.progress(through: month) == 0.25)
    }

    @MainActor @Test("Progress is capped at 1.0 (100%)")
    func progressCappedAtOne() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 100, budgetedAmount: 150)
        #expect(goal.progress(through: month) == 1.0)
    }

    @MainActor @Test("Progress is zero when target is zero")
    func zeroTargetProgress() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: .zero, budgetedAmount: 100)
        #expect(goal.progress(through: month) == 0)
    }

    @MainActor @Test("isComplete when available >= targetAmount")
    func isComplete() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 800, budgetedAmount: 800)
        #expect(goal.isComplete(through: month) == true)
    }

    @MainActor @Test("isComplete is false when not yet reached target")
    func isNotComplete() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 800, budgetedAmount: 799)
        #expect(goal.isComplete(through: month) == false)
    }

    @MainActor @Test("isComplete is false when target is zero")
    func zeroTargetNotComplete() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let goal = SavingsGoal(name: "Empty", targetAmount: .zero)
        context.insert(goal)
        try context.save()

        let month = startOfMonth(Date())
        #expect(goal.isComplete(through: month) == false)
    }

    @MainActor @Test("monthlyTarget is nil when no target date")
    func monthlyTargetNilWithoutDate() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let goal = SavingsGoal(name: "Whenever", targetAmount: 5000)
        context.insert(goal)
        try context.save()

        let month = startOfMonth(Date())
        #expect(goal.monthlyTarget(through: month) == nil)
    }

    @MainActor @Test("monthlyTarget is zero when target is zero")
    func monthlyTargetZeroForZeroTarget() throws {
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        let container = try makeTestContainer()
        let context = container.mainContext

        let goal = SavingsGoal(name: "Zero", targetAmount: .zero, targetDate: futureDate)
        context.insert(goal)
        try context.save()

        let month = startOfMonth(Date())
        #expect(goal.monthlyTarget(through: month) == Decimal.zero)
    }

    @MainActor @Test("monthlyTarget is zero when already complete")
    func monthlyTargetZeroWhenComplete() throws {
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        let (_, goal, _, month) = try makeGoalWithBudget(
            targetAmount: 1000,
            budgetedAmount: 1000,
            targetDate: futureDate
        )

        #expect(goal.monthlyTarget(through: month) == Decimal.zero)
    }

    @MainActor @Test("Default emoji is target emoji")
    func defaultEmoji() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let goal = SavingsGoal(name: "Test", targetAmount: 100)
        context.insert(goal)
        try context.save()

        #expect(goal.emoji == "🎯")
    }

    @MainActor @Test("currentAmount is zero with no linked category")
    func currentAmountNoCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let goal = SavingsGoal(name: "Unlinked", targetAmount: 1000)
        context.insert(goal)
        try context.save()

        let month = startOfMonth(Date())
        #expect(goal.currentAmount(through: month) == Decimal.zero)
    }

    @MainActor @Test("remainingAmount is correct")
    func remainingAmount() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 1000, budgetedAmount: 300)
        #expect(goal.remainingAmount(through: month) == 700)
    }

    @MainActor @Test("remainingAmount is clamped to zero when over target")
    func remainingAmountClamped() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 100, budgetedAmount: 200)
        #expect(goal.remainingAmount(through: month) == Decimal.zero)
    }

    @MainActor @Test("projectedCompletionDate returns nil with no linked category")
    func projectedCompletionNoCategory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let goal = SavingsGoal(name: "Unlinked", targetAmount: 1000)
        context.insert(goal)
        try context.save()

        let month = startOfMonth(Date())
        #expect(goal.projectedCompletionDate(through: month) == nil)
    }

    @MainActor @Test("projectedCompletionDate returns nil when already complete")
    func projectedCompletionAlreadyComplete() throws {
        let (_, goal, _, month) = try makeGoalWithBudget(targetAmount: 100, budgetedAmount: 100)
        #expect(goal.projectedCompletionDate(through: month) == nil)
    }

    @MainActor @Test("projectedCompletionDate returns nil when no budgeting history")
    func projectedCompletionNoHistory() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = BudgetCategory(name: "Savings", emoji: "💰")
        context.insert(category)

        let goal = SavingsGoal(name: "Test", targetAmount: 1000)
        goal.linkedCategory = category
        context.insert(goal)
        try context.save()

        let month = startOfMonth(Date())
        #expect(goal.projectedCompletionDate(through: month) == nil)
    }

    @MainActor @Test("projectedCompletionDate projects from month parameter, not Date()")
    func projectedCompletionProjectsFromMonth() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let category = BudgetCategory(name: "Savings", emoji: "💰")
        context.insert(category)

        let goal = SavingsGoal(name: "Test", targetAmount: 1200)
        goal.linkedCategory = category
        context.insert(goal)

        // Budget 100/month for 3 months before our reference month
        let refMonth = makeDate(year: 2025, month: 6)
        for offset in 1...3 {
            let pastMonth = Calendar.current.date(byAdding: .month, value: -offset, to: refMonth)!
            let bm = BudgetMonth(month: pastMonth)
            context.insert(bm)
            let alloc = BudgetAllocation(budgeted: Decimal(100))
            alloc.category = category
            alloc.budgetMonth = bm
            context.insert(alloc)
        }
        try context.save()

        // Available through June = 300 budgeted + 0 activity = 300
        // Remaining = 1200 - 300 = 900
        // Average budgeted = 100/month
        // Months needed = ceil(900/100) = 9
        // Projected = June 2025 + 9 months = March 2026
        let projected = goal.projectedCompletionDate(through: refMonth)
        #expect(projected != nil)

        if let projected {
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.year, .month], from: projected)
            #expect(comps.year == 2026)
            #expect(comps.month == 3)
        }
    }
}
