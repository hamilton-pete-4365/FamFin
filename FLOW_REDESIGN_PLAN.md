# FamFin Flow & Structure Redesign Plan

## Context

The design principles document describes a coherent, calm, simple financial app. The current implementation has grown organically and diverges from these principles in several structural ways: the Accounts tab has no clear identity, Settings clutters the Budget screen, Reports is over-engineered with 6+ screens, interaction patterns are inconsistent across tabs, and key actions are buried or inaccessible. This plan addresses all 13 issues from the flow audit to bring the app in line with its own principles.

---

## Phase 1: Navigation Shell & Settings Relocation

**Goal:** Fix the app skeleton before touching individual screens.

### 1A. Profile icon on every tab
- Add a consistent `person.circle` button in the **top-left (`.cancellationAction`)** toolbar position of every tab's NavigationStack.
- Tapping opens SettingsView as a `.sheet`.
- When family sharing is active, show a badge on the icon for unread activity (using `SharingManager.unreadActivityCount`).
- **Remove** the settings gear from BudgetView's toolbar (left slot).
- **Remove** the categories gear from BudgetView's toolbar (right slot) — category management moves to edit mode (Phase 3).

**Files to modify:**
- `ContentView.swift` — no changes needed (tabs stay the same)
- `BudgetView.swift` — remove settings/categories toolbar items, add profile icon
- `AccountsView.swift` — add profile icon to toolbar
- `TransactionsView.swift` — add profile icon to toolbar
- `GoalsView.swift` — add profile icon to toolbar
- `ReportsView.swift` — add profile icon to toolbar (replacing the current settings gear)
- `SharingManager.swift` — add `unreadActivityCount` property

### 1B. Double-tap Transactions tab for Add Transaction
- In `ContentView.swift`, track when the Transactions tab is tapped while already selected.
- On double-tap, set `showingNewTransaction = true` to open the Add Transaction sheet.
- Use `onChange(of: selectedTab)` to detect re-selection.

**Files to modify:**
- `ContentView.swift` — add re-selection detection logic

---

## Phase 2: Accounts Tab — Reconciliation Hub

**Goal:** Give Accounts a clear identity: "Are my accounts matching reality?"

### 2A. Fix the cross-tab navigation
- Remove `onSelectAccount` callback that jumps to the Transactions tab.
- Instead, tapping an account **pushes** `AccountDetailView` within the Accounts tab's own NavigationStack.

### 2B. New AccountDetailView (pushed view)
- **Header:** Account name, type, current balance prominently displayed.
- **Reconciliation banner:** "Last reconciled: [date]" or "Not yet reconciled" with a "Reconcile" button.
- **Transaction list:** Filtered to this account, grouped by date (reuse the same grouping logic from TransactionsView). Tapping a transaction opens EditTransactionView as a sheet.
- **Toolbar +:** Add Transaction button (pre-fills this account).

### 2C. Guided Reconciliation Flow (pushed from AccountDetailView)
New `ReconcileView`:
1. User enters their **real bank balance** (ATM-style pence entry, reuse existing pattern).
2. App shows the **difference** between entered balance and FamFin's calculated balance.
3. Show list of **uncleared transactions** (where `isCleared == false`) with checkboxes.
4. As user ticks transactions, a **running cleared balance** updates live.
5. When cleared balance matches the entered real balance, show a **success state** ("Balanced!") with a "Finish Reconciliation" button.
6. Finishing marks all checked transactions as `isCleared = true` and records the reconciliation date on the Account model.
7. If the balance doesn't match, offer "Create adjustment transaction" for the difference.

**New model property needed:** `Account.lastReconciledDate: Date?`

### 2D. Move Bank Import to Accounts tab
- Remove "Bank Import" from the `...` menu on TransactionsView.
- Add an "Import" button to AccountsView's toolbar or to AccountDetailView.
- ImportView stays the same internally — just its entry point moves.

### 2E. Move Recurring Transactions to Transactions tab (visible)
- Remove "Recurring Transactions" from the `...` menu.
- When active recurring rules exist, show a **section at the top** of TransactionsView: "3 upcoming this week" (or similar) with a "View All" that pushes RecurringTransactionsView.
- When no recurring rules exist, this section doesn't appear.
- Remove the `...` menu entirely from TransactionsView toolbar.

**Files to create:**
- `Views/Accounts/AccountDetailView.swift`
- `Views/Accounts/ReconcileView.swift`

**Files to modify:**
- `AccountsView.swift` — remove cross-tab callback, push to AccountDetailView instead
- `TransactionsView.swift` — remove `...` menu, add upcoming recurring section, remove bank import
- `ContentView.swift` — remove `navigateToAccountID` plumbing (no longer needed)
- `Models/Account.swift` — add `lastReconciledDate: Date?` property

---

## Phase 3: Budget Screen — Edit Mode & Category Detail

**Goal:** Make the Budget screen self-sufficient for category management and richer for exploration.

### 3A. Budget edit mode for categories
- Add an "Edit" / "Done" button to Budget's toolbar (in the slot freed by removing settings gear).
- In edit mode:
  - Category rows show drag handles for reorder (within a section and between sections).
  - Swipe-to-delete on subcategory rows.
  - Long-press or tap a category/header name to rename (inline or sheet).
  - "+" button appears at the bottom of each section to add a subcategory.
  - "+" button in toolbar or at the bottom of the list to add a new header group.
  - **Full cross-section drag:** Dragging a subcategory from one header's section to another re-parents it. This requires flattening the category list during edit mode to enable cross-section `onMove`, then reconstructing the parent/child relationships on drop. The section boundaries are defined by header categories in the flattened list.
- **Deleting a category with transactions:** Show a confirmation dialog: "This category has 12 transactions. Move them to:" with a category picker for bulk reassignment. Option to "Reassign individually later" which moves them to Uncategorised.
- In edit mode, the budgeted/available columns are hidden to make room for reorder handles. The focus is structural, not numerical.
- ManageCategoriesView is **kept** as a fallback (accessible from the profile/settings screen or from the empty state) but is no longer the primary path.

### 3B. Category detail — change from sheet to pushed view
- Tapping a category name or available amount on the Budget screen **pushes** to `CategoryDetailView` (new pushed view, replacing the current `CategoryDetailSheet`).
- The pushed view contains:
  - Summary header: emoji, name, Budgeted / Activity / Available for the month.
  - Linked goals section (existing `CategoryGoalRow`, tapping navigates to GoalDetailView).
  - Transaction list for this category/month.
  - **"Add Transaction" button** in the toolbar (pre-fills category).
  - Tapping a transaction opens EditTransactionView as a sheet.
- The current `CategoryDetailSheet` is removed.
- The tappable budgeted-amount field on the budget row stays as inline editing (no change).

**Files to create:**
- `Views/Budget/CategoryDetailView.swift` (pushed view replacing CategoryDetailSheet)

**Files to modify:**
- `BudgetView.swift` — add edit mode, remove sheet presentation for category detail, replace with navigationDestination push, add edit/done toggle, add toolbar items for edit mode
- `ManageCategoriesView.swift` — keep but mark as secondary path

---

## Phase 4: Standardise Interaction Patterns

**Goal:** "Always push" for detail, "always sheet" for creation.

### 4A. Goals — already correct (push to GoalDetailView) ✓

### 4B. Budget — change to push (Phase 3B above) ✓

### 4C. Accounts — change to push (Phase 2A above) ✓

### 4D. Reports — sub-reports stay as push ✓ (already NavigationLink)

### 4E. Transactions — tapping a row currently opens EditTransactionView as a sheet
- **Decision:** Keep this as a sheet. Editing is a focused modal task (the principles say "sheets for creation" but editing is the same pattern — a focused form). This is consistent with how Add Transaction works.
- No change needed here.

### 4F. Swipe-to-delete with confirmation on transaction rows
- Add `.swipeActions(edge: .trailing)` with a red "Delete" button to transaction rows.
- Tapping the swipe delete shows a `.confirmationDialog`: "Delete this transaction? This will update your account balance and budget."
- The delete button inside EditTransactionView also gets a `.confirmationDialog` (currently it's an immediate delete).

**Files to modify:**
- `TransactionsView.swift` — add swipe action with confirmation to transaction rows
- `BudgetView.swift` (CategoryDetailView) — same swipe action on category transaction rows
- `TransactionsView.swift` (EditTransactionView) — add confirmation dialog to delete button

---

## Phase 5: Reports Simplification

**Goal:** Sub-reports are the core. Main screen shows favourited summaries. Delete report settings/custom charts.

### 5A. Remove ReportSettingsView and custom chart configuration
- Delete `ReportSettingsView.swift`.
- Remove the settings gear from the Reports toolbar.
- Remove `ReportSettings.swift` service (or simplify to just store favourite state).

### 5B. Redesign Reports main screen
- **Top section:** Favourite sub-report summary cards. Each card shows a compact preview of the sub-report's key data (e.g. mini donut for Spending Breakdown, mini bar for Income vs Expense). Tapping pushes to the full sub-report.
- **Bottom section:** "All Reports" list showing any un-favourited reports. Tapping pushes to the full sub-report. Star icon to toggle favourite.
- Default: all 4 sub-reports are favourited initially.
- The current balance charts (BalanceChartCard, BalanceBarChart) and the report settings/custom charts system are **removed entirely**. The 4 sub-reports are the complete reports offering.
- **Available sub-reports:** Spending Breakdown, Spending Trends, Income vs Expenses, Top Spenders.

### 5C. Sub-report detail views
- No structural change — SpendingBreakdownView, SpendingTrendsView, IncomeVsExpenseView, TopSpendersView stay as pushed views.
- The existing BalanceChartCard/BalanceBarChart components can be removed (or kept only if needed by a sub-report internally).

**Files to create:**
- `Views/Reports/ReportSummaryCard.swift` (compact preview card for favourited reports)

**Files to modify:**
- `ReportsView.swift` — complete rewrite of main screen layout
- `ReportSettings.swift` — simplify to just store which reports are favourited

**Files to delete:**
- `ReportSettingsView.swift`

---

## Phase 6: Goals ↔ Budget Cross-Reference

**Goal:** Bidirectional navigation between Goals and Budget.

### 6A. GoalDetailView — visible budget section
- `GoalDetailLinkedCategoryView` already exists and shows category name + stats.
- Enhance it to show **Budgeted / Activity / Available** for the linked category in the current month (matching the CategoryDetailView summary header).
- Make it tappable to push to `CategoryDetailView`.
- If the category is underfunded this month, show a subtle warning: "This category needs £X more to stay on track."

### 6B. CategoryDetailView — goal section (already planned in Phase 3B)
- The existing `CategoryGoalRow` pattern carries over to the new pushed CategoryDetailView.
- Tapping a goal row pushes to GoalDetailView.

**Files to modify:**
- `GoalDetailView.swift` — enhance GoalDetailLinkedCategoryView with budget data and navigation

---

## Phase 7: Sharing Activity Badge

**Goal:** Surface family activity without burying it.

### 7A. SharingManager badge count
- Add a computed property `unreadActivityCount` to SharingManager.
- Track "last seen" timestamp in UserDefaults. Activity entries newer than this are "unread."
- When the user opens the Activity Feed (from the profile/settings sheet), mark all as read.

### 7B. Profile icon badge
- The `person.circle` icon on each tab shows an overlay badge when `unreadActivityCount > 0`.
- Small red dot or number badge, consistent across all tabs.

**Files to modify:**
- `SharingManager.swift` — add unread tracking
- `ActivityFeedView.swift` — mark entries as read on appear
- All tab views (from Phase 1A) — badge the profile icon

---

## Phase 8: Empty States & Polish

### 8A. Budget empty state improvement
- Replace "Tap the gear icon" text with a direct "Set Up Categories" button that enters edit mode (or pushes ManageCategoriesView if edit mode requires existing categories).

### 8B. Confirm delete on all destructive actions
- EditTransactionView: add `.confirmationDialog` to delete button.
- EditRecurringTransactionView: same (currently also immediate delete).
- EditAccountView: already has `.alert` for delete — verify it follows the pattern.

### 8C. Add Transaction from Category Detail
- The new CategoryDetailView (Phase 3B) has an "Add Transaction" button in the toolbar.
- Opens AddTransactionView as a sheet with category pre-selected.

---

## Implementation Order

The phases above are listed in dependency order:

1. **Phase 1** (shell + settings) — foundational, unblocks everything
2. **Phase 2** (accounts) — new views, no dependencies on other phases
3. **Phase 3** (budget edit mode + category detail) — largest phase, core UX change
4. **Phase 4** (interaction standardisation) — cleanup, follows from Phase 3
5. **Phase 5** (reports) — independent, can be done in parallel with 3-4
6. **Phase 6** (goals ↔ budget) — depends on Phase 3 (CategoryDetailView)
7. **Phase 7** (sharing badge) — independent, small
8. **Phase 8** (polish) — final pass

---

## Key Files Summary

### New files to create
| File | Purpose |
|------|---------|
| `Views/Accounts/AccountDetailView.swift` | Pushed account detail with transactions and reconcile entry |
| `Views/Accounts/ReconcileView.swift` | Guided reconciliation flow |
| `Views/Budget/CategoryDetailView.swift` | Pushed category detail (replaces CategoryDetailSheet) |
| `Views/Reports/ReportSummaryCard.swift` | Compact preview card for favourited reports |

### Files to significantly modify
| File | Changes |
|------|---------|
| `BudgetView.swift` | Remove settings/categories toolbar, add profile icon, add edit mode, replace sheet→push for category detail |
| `AccountsView.swift` | Remove cross-tab jump, push to AccountDetailView, add import button, add profile icon |
| `TransactionsView.swift` | Remove `...` menu, add recurring section, add swipe-delete, add profile icon |
| `GoalsView.swift` | Add profile icon |
| `ReportsView.swift` | Complete rewrite: favourites + all reports layout, remove settings gear, add profile icon |
| `ContentView.swift` | Add double-tap detection for Transactions tab, remove navigateToAccountID plumbing |
| `GoalDetailView.swift` | Enhance linked category section with budget data and navigation |
| `SharingManager.swift` | Add unread activity count |

### Files to delete
| File | Reason |
|------|--------|
| `ReportSettingsView.swift` | Custom chart configuration removed |

### Model changes
| Model | Change |
|-------|--------|
| `Account` | Add `lastReconciledDate: Date?` with default value |

---

## Verification

After implementation, verify each change:

1. **Profile icon:** Visible on all 5 tabs, opens Settings sheet, badge shows when sharing activity exists.
2. **Double-tap Transactions tab:** Opens Add Transaction from any tab.
3. **Accounts tab:** Tapping account pushes to detail (no tab switch). Reconciliation flow works end-to-end. Import accessible.
4. **Budget edit mode:** Can reorder, rename, delete, add categories. Delete with transactions prompts reassignment. Exit edit mode returns to normal budget view.
5. **Category detail push:** Tapping category on Budget pushes detail view. Can add transaction from there. Can navigate to linked goal.
6. **Goal detail:** Shows linked category budget status. Can tap through to category detail.
7. **Reports:** Main screen shows favourite cards. Tap through to sub-reports. No settings gear. All 4 sub-reports accessible.
8. **Delete confirmations:** Transaction delete (swipe and edit screen) both show confirmation dialog.
9. **Recurring section:** Visible on Transactions when rules exist. Links to RecurringTransactionsView.
10. **Build:** `xcodebuild -scheme FamFin -destination 'platform=iOS Simulator,name=iPhone 16' build` succeeds with no errors.
