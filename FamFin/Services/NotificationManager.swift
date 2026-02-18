import Foundation
import SwiftData
import UserNotifications

/// Manages local notifications for budget alerts, weekly digests,
/// and month-end reminders. All notifications are local — no server required.
@MainActor @Observable
final class NotificationManager {

    // MARK: - Persisted settings

    /// Whether category threshold alerts are enabled (e.g. 80%/100% spent)
    var categoryAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(categoryAlertEnabled, forKey: Keys.categoryAlertEnabled) }
    }

    /// Whether weekly spending summary notifications are enabled
    var weeklyDigestEnabled: Bool {
        didSet { UserDefaults.standard.set(weeklyDigestEnabled, forKey: Keys.weeklyDigestEnabled) }
    }

    /// Whether month-end budget review reminders are enabled
    var monthEndReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(monthEndReminderEnabled, forKey: Keys.monthEndReminderEnabled) }
    }

    /// The threshold percentage at which a category alert fires (default 0.8 = 80%)
    var categoryThreshold: Double {
        didSet { UserDefaults.standard.set(categoryThreshold, forKey: Keys.categoryThreshold) }
    }

    /// Current notification authorisation status, refreshed on demand
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.categoryAlertEnabled = defaults.bool(forKey: Keys.categoryAlertEnabled)
        self.weeklyDigestEnabled = defaults.bool(forKey: Keys.weeklyDigestEnabled)
        self.monthEndReminderEnabled = defaults.bool(forKey: Keys.monthEndReminderEnabled)

        let stored = defaults.double(forKey: Keys.categoryThreshold)
        self.categoryThreshold = stored > 0 ? stored : 0.8
    }

    // MARK: - Permission

    /// Requests notification permission from the user.
    /// Returns `true` if authorisation was granted.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }

    /// Refreshes the cached `authorizationStatus` from the system.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Update notifications

    /// Evaluates current budget data and schedules/cancels notifications accordingly.
    /// Call this whenever the app becomes active or after transactions change.
    func updateNotifications(context: ModelContext) async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized else { return }

        if categoryAlertEnabled {
            scheduleCategoryAlerts(context: context)
        } else {
            cancelNotifications(withPrefix: Prefix.categoryAlert)
        }

        if weeklyDigestEnabled {
            scheduleWeeklyDigest(context: context)
        } else {
            cancelNotifications(withPrefix: Prefix.weeklyDigest)
        }

        if monthEndReminderEnabled {
            scheduleMonthEndReminder()
        } else {
            cancelNotifications(withPrefix: Prefix.monthEndReminder)
        }
    }

    /// Cancels all pending FamFin notifications.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Sends a test notification immediately (fires after 1 second).
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "FamFin"
        content.body = "Notifications are working! You'll receive budget alerts here."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "famfin.test",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Category threshold alerts

    /// Checks each budgetable category in the current month. If spending
    /// has reached the threshold (or 100%), schedules a one-shot notification.
    private func scheduleCategoryAlerts(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let currentMonth = calendar.date(from: components) else { return }

        // Fetch all categories that are budgetable (not headers, not system)
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { !$0.isHeader && !$0.isSystem }
        )
        guard let categories = try? context.fetch(descriptor) else { return }

        // Collect identifiers to keep; remove stale ones later
        var activeIdentifiers: [String] = []

        for category in categories {
            let budgeted = category.budgeted(in: currentMonth)
            guard budgeted > .zero else { continue }

            let activity = category.activity(in: currentMonth)
            // Activity is negative for spending
            let spent = -activity
            guard spent > .zero else { continue }

            let ratio = Double(truncating: (spent / budgeted) as NSDecimalNumber)

            if ratio >= 1.0 {
                let identifier = "\(Prefix.categoryAlert)\(category.name).exceeded"
                scheduleImmediateAlert(
                    identifier: identifier,
                    title: "\(category.emoji) \(category.name) Over Budget",
                    body: "You've spent more than your \(category.name) budget this month."
                )
                activeIdentifiers.append(identifier)
            } else if ratio >= categoryThreshold {
                let percent = Int(ratio * 100)
                let identifier = "\(Prefix.categoryAlert)\(category.name).threshold"
                scheduleImmediateAlert(
                    identifier: identifier,
                    title: "\(category.emoji) \(category.name) at \(percent)%",
                    body: "You've used \(percent)% of your \(category.name) budget this month."
                )
                activeIdentifiers.append(identifier)
            }
        }
    }

    /// Schedules a one-shot notification that fires in 5 seconds.
    /// Uses a unique identifier so it replaces (not duplicates) previous alerts.
    private func scheduleImmediateAlert(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Fire in 5 seconds — gives a brief delay so alerts don't spam on app open
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weekly digest

    /// Schedules a repeating weekly notification for Sunday at 18:00.
    /// Includes the total spent this week and top spending categories.
    private func scheduleWeeklyDigest(context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        // Calculate week spending for the notification body
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now

        let descriptor = FetchDescriptor<Transaction>()
        let transactions = (try? context.fetch(descriptor)) ?? []

        var weekTotal = Decimal.zero
        var categoryTotals: [String: Decimal] = [:]

        for transaction in transactions {
            guard transaction.date >= weekStart,
                  transaction.date <= now,
                  transaction.type == .expense,
                  transaction.account?.isBudget == true else { continue }
            weekTotal += transaction.amount
            let name = transaction.category?.name ?? "Uncategorised"
            categoryTotals[name, default: .zero] += transaction.amount
        }

        let topCategories = categoryTotals.sorted { $0.value > $1.value }.prefix(3)
        let topList = topCategories.map { "\($0.key)" }.joined(separator: ", ")

        let currencyCode = UserDefaults.standard.string(forKey: CurrencySettings.key) ?? "GBP"
        let formattedTotal = formatGBP(weekTotal, currencyCode: currencyCode)

        var body = "You spent \(formattedTotal) this week."
        if !topList.isEmpty {
            body += " Top categories: \(topList)."
        }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Spending Summary"
        content.body = body
        content.sound = .default

        // Sunday at 18:00
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(Prefix.weeklyDigest)sunday",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Month-end reminder

    /// Schedules a notification for the 28th of each month at 10:00.
    /// This is a simple repeating reminder that doesn't vary month to month.
    private func scheduleMonthEndReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Month-End Budget Review"
        content.body = "Your month is ending soon — review your budget and prepare for next month!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.day = 28
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(Prefix.monthEndReminder)28th",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    /// Removes all pending notification requests whose identifier starts with the given prefix.
    private func cancelNotifications(withPrefix prefix: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let requests = await center.pendingNotificationRequests()
            let matching = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map(\.identifier)
            if !matching.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: matching)
            }
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let categoryAlertEnabled = "notification.categoryAlertEnabled"
        static let weeklyDigestEnabled = "notification.weeklyDigestEnabled"
        static let monthEndReminderEnabled = "notification.monthEndReminderEnabled"
        static let categoryThreshold = "notification.categoryThreshold"
    }

    private enum Prefix {
        static let categoryAlert = "famfin.category."
        static let weeklyDigest = "famfin.weekly."
        static let monthEndReminder = "famfin.monthend."
    }
}
