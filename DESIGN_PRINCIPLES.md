# FamFin Design Principles

A comprehensive design system and set of principles for building a best-in-class family finance app. This document should be read and factored into every feature, view, and interaction built in FamFin.

---

## 0. The North Star

The finished FamFin should feel like a single, coherent surface — not a collection of features bolted together. When a user opens it, they should see their financial life clearly, act on it quickly, and close it knowing exactly where they stand.

**The experience in one sentence:** Open the app, see your budget health at a glance, make any necessary changes in seconds, and get on with your day.

**What "best in class" means for FamFin:**
- It feels inevitable — every screen, every flow, every label feels like the only way it could have been designed.
- It disappears into use — users think about their money, not about the app. The tool never draws attention to itself.
- It respects time — the most common tasks (check budget, log a transaction, see if a goal is on track) complete in under 5 seconds.
- It earns trust — through visual consistency, predictable behaviour, and honest presentation of data. Nothing feels arbitrary.

**What "best in class" does NOT mean:**
- It does not mean "most features." A finance app with 50 mediocre screens loses to one with 10 exceptional screens.
- It does not mean "most customisable." Options create cognitive overhead. Decisions made well on the user's behalf are a gift, not a limitation.
- It does not mean "most visually striking." Attention-grabbing design works against calm confidence. Polish should be felt, not seen.

---

## 1. Design Philosophy

### 1.1 Core Design Pillars

**Calm Confidence** — Money is stressful. FamFin should reduce anxiety, not create it. Every screen should help users feel in control without overwhelming them. Use restrained color, generous whitespace, and clear hierarchy to project calm authority.

**Ruthless Simplicity** — The best interface is the one with the least to learn. Every element on screen must earn its place. If two features solve the same problem, keep the better one and remove the other. If a setting could be a sensible default, make it the default and delete the setting. If a screen can be removed by folding its content into an existing screen, remove it. The goal is not "more features" — it is fewer, better surfaces that each do their job completely.

**Progressive Disclosure** — Show only what matters right now. The budget screen shows totals; tap for the breakdown. The transaction list shows the essentials; tap for the full story. Never front-load complexity. Let users drill in at their own pace.

**Immediate Feedback** — Every action should feel acknowledged. Tapping a budget cell enters edit mode instantly. Saving a transaction shows the balance update live. Reaching a goal triggers celebration. The app should feel responsive and alive, never sluggish or uncertain.

**Honest Data** — Never obscure, round, or beautify financial data in ways that could mislead. When something is overspent, show it clearly. When the budget is healthy, let the user enjoy that fact. Trust users with the truth.

### 1.2 Design Personality

FamFin's personality is **a knowledgeable friend who's great with money** — approachable but competent, warm but precise. It is not a stern accountant (too intimidating), not a playful toy (too unserious for real money), and not a corporate dashboard (too cold for family use).

This personality manifests as:
- Friendly category emojis alongside precise decimal amounts
- Celebration moments (confetti, progress rings) balanced with serious overspent warnings
- Conversational empty states rather than blank screens
- A green-forward color palette that suggests growth and health

### 1.3 Elegance Through Restraint

The hallmark of a truly polished app is not what it has, but what it doesn't need. Apply these filters to every design decision:

**One way to do each thing — but let users act on what they can see.** There should be exactly one *workflow* for each task: one form for adding a transaction, one form for editing a budget allocation, one way to create a goal. What this does *not* mean is forcing users to navigate away from their current context to act on something visible in front of them. If a transaction appears in a category detail sheet, tapping it should open the same edit form that the Transactions tab uses — same destination, different entry point. The principle is one consistent workflow, not one rigid starting point. Multiple entry points converge on the same experience; multiple *different* experiences for the same task is the problem. Similarly, convenience shortcuts (swipe actions, keyboard shortcuts) are fine when they accelerate an action that already has a clear primary path — they're faster doors into the same room, not different rooms.

**Earn every element.** Before adding any control, label, icon, or section to a screen, ask: "What happens if I remove this?" If the answer is "nothing important," remove it. If the answer is "the user loses context," keep it but consider whether it belongs at this level or one level deeper.

**Prefer smart defaults over settings.** Every setting is an admission that the designer couldn't decide. When the right answer is knowable (most recent account, today's date, the user's currency), fill it in. Only expose a setting when users genuinely have different correct answers and the choice matters.

**Density is not complexity.** A screen can show a lot of data and still feel simple if it has clear hierarchy and consistent patterns. The budget screen is dense but readable because every row follows the same structure. Complexity comes from inconsistency, not quantity.

**Delete before you add.** When a new feature is requested, first ask whether an existing surface can absorb it naturally. A new tab, new screen, or new modal is expensive — it's another place users have to learn exists. The best new feature is one that makes an existing screen more useful, not one that adds a new screen.

---

## 2. Visual Design System

### 2.1 Color Palette

#### Brand Colors

| Role | Light Mode | Dark Mode | Usage |
|------|-----------|-----------|-------|
| **Accent** (Forest Green) | `rgb(6, 64, 43)` | `rgb(10, 122, 80)` | Primary actions, selected states, tint color |
| **Warning** (Amber) | `rgb(204, 119, 0)` | `rgb(229, 163, 38)` | Overspent pills, caution states |

#### Semantic Colors

Use system semantic colors to ensure automatic light/dark adaptation:

| Semantic Role | Color | When to Use |
|---------------|-------|-------------|
| **Positive amount** | `.green` or `.accentColor` | Income, funded categories, positive "To Budget" |
| **Negative amount** | `.red` | Expenses, overspent categories, negative "To Budget" |
| **Neutral amount** | `.secondary` | Transfers, zero balances, informational amounts |
| **Standard text** | `.primary` | Body copy, labels, navigation titles |
| **Supporting text** | `.secondary` | Timestamps, metadata, descriptions |
| **Muted text** | `.tertiary` | Placeholders, disabled states, footnotes |
| **Surface** | System grouped background | Card backgrounds, section backgrounds |
| **Destructive** | `.red` | Delete actions, irreversible operations |

#### Color Principles

- **Never rely on color alone** to convey meaning. Pair red/green amounts with +/- signs or explicit labels like "Overspent" and "Available".
- **Maintain contrast ratios** of at least 4.5:1 for body text and 3:1 for large text (WCAG AA).
- **Limit the active palette** on any single screen to accent + one semantic color + neutrals. Avoid rainbow screens.
- **Dark mode is not an afterthought.** Always verify both appearances. Use system semantic colors which adapt automatically.

### 2.2 Typography

All typography uses Dynamic Type exclusively. Never hard-code font sizes.

#### Type Scale (Roles, Not Sizes)

| Role | Style | Weight | Usage |
|------|-------|--------|-------|
| **Screen title** | `.largeTitle` | System default | Navigation bar titles |
| **Hero number** | `.title` | `.bold()` | "To Budget" amount, account totals |
| **Section amount** | `.title2` | `.bold()` | Category available amounts |
| **Card heading** | `.title3` | `.bold()` | Goal names, report chart titles |
| **Row title** | `.headline` | System default | Transaction payees, category names |
| **Body** | `.body` | System default | Descriptions, form fields, notes |
| **Supporting** | `.subheadline` | System default | Secondary row info, date labels |
| **Caption** | `.caption` | System default | Timestamps, metadata, footnotes |
| **Overline** | `.caption2` + `.textCase(.uppercase)` | System default | Section labels, status badges |

#### Typography Principles

- **Bold sparingly.** Use `.bold()` only for primary numbers and headings. If everything is bold, nothing is.
- **Use weight for hierarchy, not size.** Two lines of text at the same size but different weights create clear parent-child relationships.
- **Left-align text, right-align numbers.** Financial amounts should always be trailing-aligned within their container for scannability.
- **Tabular figures for amounts.** Numbers representing money should use `.monospacedDigit()` so decimal points and digits align vertically in lists.
- **Never truncate amounts.** Abbreviate labels if needed, but financial figures must always display in full.

### 2.3 Iconography

- Use **SF Symbols exclusively** for consistency with the iOS ecosystem.
- Prefer **filled variants** for tab bar icons and primary actions.
- Prefer **outline variants** for secondary/toolbar actions.
- Always provide a text label alongside icons — never use an icon-only button without an accessibility label at minimum, and prefer visible text where space allows.
- Category emojis are the exception to SF Symbols — they add personality and are user-facing identifiers.

### 2.4 Spacing & Layout

#### Spacing Scale

Rather than arbitrary pixel values, use a consistent base-4 scale:

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4pt | Inline spacing, icon-to-text gap |
| `sm` | 8pt | Tight group spacing, compact lists |
| `md` | 12pt | Standard list item padding, card internal spacing |
| `lg` | 16pt | Section spacing, screen edge insets |
| `xl` | 24pt | Major section separation |
| `xxl` | 32pt | Hero element breathing room |

#### Layout Principles

- **Screen edges get `lg` (16pt) insets.** This is the minimum breathing room from the device edge.
- **Cards get `md` to `lg` internal padding** (12-16pt) depending on density.
- **Related items within a group use `sm` (8pt) spacing.** Category rows within a header group, for example.
- **Unrelated sections use `xl` (24pt) separation.** The gap between "Budget Accounts" and "Tracking Accounts" sections.
- **Tap targets must be at least 44x44pt.** This is Apple's minimum; prefer larger for primary actions.
- **Use system list insets** unless a custom layout demands otherwise. Consistency with iOS conventions reduces cognitive load.

### 2.5 Corner Radii

| Element | Radius | Modifier |
|---------|--------|----------|
| Cards / Sections | 12pt | `.clipShape(.rect(cornerRadius: 12))` |
| Buttons / Pills | 10pt | `.clipShape(.rect(cornerRadius: 10))` |
| Input fields | 8pt | `.clipShape(.rect(cornerRadius: 8))` |
| Small badges | 6pt | `.clipShape(.rect(cornerRadius: 6))` |
| Circular elements | `.infinity` | `.clipShape(.circle)` |

Use consistent radii per element type. Nested rounded rects should have the inner radius reduced by the padding amount (e.g., a 12pt card with 8pt padding should have 4pt inner element radii) to maintain optical consistency.

### 2.6 Elevation & Shadow

Use shadow sparingly — it should create subtle depth, not dramatic drama.

| Level | Shadow | Usage |
|-------|--------|-------|
| **Flat** | None | Default list rows, inline content |
| **Raised** | `color: .black.opacity(0.06), radius: 4, y: 2` | Cards within scroll views |
| **Bar** | None (material-based) | Inline keypads, action bars — use `.bar` background material for translucency that adapts to light/dark mode and scroll content beneath |
| **Floating** | `color: .black.opacity(0.08), radius: 8, y: 4` | Floating action areas |
| **Modal** | System sheet shadow | Sheets, popovers (handled by SwiftUI) |

In dark mode, reduce shadow opacity or rely on surface color differentiation instead. The `.bar` material level handles dark mode automatically through system translucency.

---

## 3. Interaction Design

### 3.1 Navigation Model

#### Tab-Based Architecture

The five-tab structure (Budget, Accounts, Transactions, Goals, Reports) is the app's skeleton. Principles:

- **Budget is home.** It's the first tab and the screen users see most. It answers "Where is my money going?"
- **Tabs represent nouns, not verbs.** Each tab is a domain, not an action. Creation happens within each domain via add buttons.
- **Cross-tab navigation is intentional.** Tapping an account navigates to filtered transactions. Tapping a category's transactions shows them in context. These cross-references build a connected experience.
- **Sheets for creation, push for detail.** Adding a transaction presents a sheet (focused, modal task). Viewing a goal pushes to a detail view (exploration, drill-down).
- **Every piece of data has one home, but can be acted on anywhere it appears.** Accounts live on the Accounts tab. Transactions live on the Transactions tab. But when a transaction appears in a category detail or a goal summary, the user should be able to tap through to view or edit it right there — opening the same form, just from a different starting point. The distinction: *browsing and managing* a data type happens in its home tab; *acting on a specific item* you've already found should never require navigating elsewhere first.

#### Standardised Tab Header Pattern

Budget and Transactions share a common header structure. Future tabs should follow the same pattern to maintain visual cohesion:

- **Toolbar:** Profile button (`.topBarLeading`), tab title (`.principal`), add-transaction `+` button plus an optional context menu (`.primaryAction`). Use `ToolbarSpacer(.fixed)` between the + and the menu.
- **Month selector:** Directly below the toolbar. `chevron.left` / tappable month label with `MonthYearPicker` popover / `chevron.right`. A "Today" pill appears between the chevron and month label when not on the current month. Horizontal swipe on the screen body also navigates months.
- **Status area:** Below the month selector. Status pills on Budget; filter chip + search bar on Transactions. Each tab uses this zone for its own contextual indicators.

This consistent skeleton means switching between tabs feels like moving within one surface, not jumping between different apps.

#### Navigation Depth Limits

- **Maximum 3 levels deep** from any tab. If a flow requires more, rethink the information architecture.
- **Every pushed view must have a clear back path.** Users should never feel lost.
- **Sheets dismiss with a clear action** (Save, Cancel) — never auto-dismiss without user intent.

#### The "Where Does This Live?" Test

Before adding any new screen or feature, answer: "If a user wanted to find this, which tab would they tap?" If the answer is ambiguous, the feature either belongs on the tab where its primary data lives, or it should be folded into an existing screen rather than given its own. Never add a screen just because a feature exists — add a screen only when the user needs a dedicated place to focus on a task.

### 3.2 Touch & Gesture Patterns

| Gesture | Usage | Feedback |
|---------|-------|----------|
| **Tap** | Select, navigate, toggle | Highlight state + haptic (`.selection`) |
| **Long press** | Context menu, reorder mode | Haptic (`.impact(.medium)`) + menu/scale |
| **Swipe leading** | Quick positive action (mark cleared) | Green reveal + haptic |
| **Swipe trailing** | Delete / destructive action | Red reveal + haptic |
| **Swipe horizontal** | Navigate between time periods (months) | Animated content transition |
| **Pull down** | Refresh data | Standard refresh indicator |
| **Drag** | Reorder items (categories, accounts) | Haptic on pickup + drop |

#### Gesture Principles

- **One gesture per direction per context.** Don't overload swipe-left with multiple actions. Use a context menu for additional options.
- **Swipe actions mirror iOS conventions.** Trailing = destructive (red), leading = constructive (green/blue).
- **Never require gestures for critical actions.** Every gesture-triggered action must also be accessible via a visible button or menu.

### 3.3 Haptic Language

Haptics create a tactile vocabulary. Use them consistently:

| Haptic | When |
|--------|------|
| `.selection` | Focus changes (tapping a budget cell to edit) |
| `.impact(.light)` | Toggling states, tapping chips |
| `.impact(.medium)` | Confirming saves, closing modals with changes |
| `.success` | Goal milestones, successful import, budget fully allocated |
| `.warning` | Overspent category, failed validation |
| `.error` | Delete confirmation, sync failure |

**Always** respect `accessibilityReduceMotion` — when enabled, skip decorative haptics but retain confirmation haptics (success, error).

### 3.4 Data Entry Patterns

#### The ATM-Style Number Pad

FamFin uses pence-based entry for amounts: digits build from the right, like an ATM. This is faster and less error-prone than decimal entry for financial amounts.

- Display the formatted currency as the user types (e.g., typing "1536" shows "£15.36").
- Clear with a single backspace-like action (delete last digit).
- Show a visible "0.00" placeholder before any input.
- **Math operators (+/−)** allow relative budgeting. Pressing + or − appends to the current value, showing a secondary expression line (e.g., "£15.00 + £5.00") below the running total. The = key resolves the expression. This lets users think in adjustments ("add £20 more") rather than recalculating totals.
- Make contextual suggestions (e.g. historical data, averages, goal targets) available via a **Quick Fill popover** during amount entry so users can fill values quickly without mental arithmetic. Quick Fill presents last month's budgeted and spent amounts alongside 12-month averages, tapping a suggestion applies the value directly to the keypad.

#### Form Design

- **Labels above fields**, not inline (better for Dynamic Type scaling).
- **Inline validation** — show errors immediately below the field as the user types, not on submit.
- **Disable the save button** until the form is valid. Use a `.disabled()` state with reduced opacity.
- **Pre-populate intelligently.** When adding a transaction, default to today's date and the most-used account. When budgeting, suggest last month's amount.
- **Confirm destructive changes.** Editing a recurring transaction should ask "This occurrence only" or "This and future."

### 3.5 Loading, Empty & Error States

Every view has four states. Design all four:

#### Loading State
- Use a subtle **shimmer/skeleton** for initial data load.
- For sync refreshes, use the standard pull-to-refresh indicator.
- Never show a blank screen. A loading state is better than nothing.

#### Empty State
- Use `ContentUnavailableView` with an appropriate SF Symbol, a short title, and a one-line description.
- **Include a call to action.** "No transactions yet" with an "Add Transaction" button is better than just "No transactions yet."
- Empty states should feel encouraging, not scolding. "Start budgeting" not "You haven't set up anything."

#### Content State
- The happy path. Design this first, then ensure the other three states are equally considered.

#### Error State
- Show **what went wrong** in plain language ("Couldn't load your transactions").
- Show **what to do** ("Pull down to retry" or "Check your internet connection").
- Never show raw error codes, exception names, or stack traces.

---

## 4. Motion & Animation

### 4.1 Animation Principles

- **Purposeful, not decorative.** Every animation should help the user understand what changed and where. If removing it creates confusion, it's purposeful. If removing it makes no difference, delete it.
- **Fast and responsive.** Default to 0.2-0.3s durations with `.easeInOut` or `.spring` curves. Finance apps must feel snappy, not sluggish.
- **Interruptible.** Use spring animations that can be redirected mid-flight. Never lock the UI during an animation.
- **Respect user preferences.** Check `accessibilityReduceMotion`. When enabled, replace animations with instant state changes (crossfade is acceptable).

### 4.2 Standard Transitions

| Transition | Duration | Curve | Usage |
|------------|----------|-------|-------|
| **Push/Pop** | System default | System spring | NavigationStack transitions |
| **Sheet present** | System default | System spring | Modal presentation |
| **State change** | 0.2s | `.easeInOut` | Toggle, selection highlight |
| **Number change** | 0.35s | `.spring(response: 0.35)` | Budget amounts, counters |
| **Progress fill** | 0.5s | `.easeOut` | Progress rings, bar charts |
| **Celebration** | 1.5s | Custom | Confetti on goal milestones |

### 4.3 Micro-Interactions

- **Budget cell focus:** Tap in = accent-tinted row background (`.accentColor.opacity(0.12)`) with `.selection` haptic. The keypad slides up from the bottom with a spring animation. Tap another row = auto-save the current value, shift focus immediately, light haptic on save.
- **Budget number update:** Budgeted and available amounts use `.contentTransition(.numericText())` so digits roll smoothly between values rather than snapping.
- **Status pills:** The "To Budget" pill updates its amount live as allocations change, reflecting the new balance without any page reload or manual refresh.
- **Math expression appearance:** When a + or − operator is pressed, a secondary expression line fades in below the budgeted amount (`.transition(.opacity)`). The row may grow taller; if it extends below the visible area, the list scrolls the minimum distance needed to reveal it.
- **Goal progress ring:** Fill animates from current to new value on contribution.
- **Transaction save:** Row inserts with a standard list insert animation and the balance header updates simultaneously.
- **Category available amount:** When budget allocation changes, the available column animates to its new value.

---

## 5. Information Architecture

### 5.1 Content Hierarchy per Screen

Every screen should have a clear top-to-bottom priority:

1. **Status / Hero** — The most important number or state (e.g., "To Budget: £1,234.56" or "Goal: 72% complete"). This is what the user glances at before deciding to engage further.
2. **Primary content** — The main list or data (budget categories, transactions, goal list). This is what users interact with.
3. **Supporting actions** — Secondary controls (filters, sort, settings gear). Accessible but not competing for attention.

### 5.2 Scannability Rules

- **Left = identity, Right = value.** In any row, the left side identifies what it is (category name, payee), the right side shows the number.
- **Group related items.** Use section headers with clear labels. "Budget Accounts" and "Tracking Accounts" not a flat mixed list.
- **Limit list columns.** Show at most 3 columns of data in a row (name, secondary info, amount). More than that requires a detail view.
- **Zebra striping is unnecessary** in iOS — rely on system list separators and grouping instead. List separators should extend edge-to-edge (full bleed) for a clean, uncluttered look.

### 5.3 Number Formatting

- **Always show the currency symbol.** "£15.36" not "15.36".
- **Use proper locale formatting.** Comma vs period separators must follow the selected currency's conventions.
- **Two decimal places for all currencies** except JPY (zero decimals).
- **Use `.monospacedDigit()`** for amount columns so digits align vertically.
- **Sign convention:** Expenses are negative when contextually appropriate (transaction lists, activity breakdowns), but displayed as positive with color coding in budget views (where the sign is implied by the column: "Budgeted" vs "Activity" vs "Available").

---

## 6. Accessibility

### 6.1 Non-Negotiable Requirements

These are not enhancements — they are baseline requirements:

- **Every interactive element** has an `accessibilityLabel` that describes its purpose.
- **Every custom control** has an `accessibilityHint` explaining how to use it.
- **All images and emojis** are either described or marked `.accessibilityHidden(true)` if decorative.
- **Dynamic Type** is supported at every size from `xSmall` to `accessibility5`. No layouts break at any size.
- **Color is never the sole indicator** of state. Red amounts also have a "-" sign. Green amounts also have a "+" or "Available" label.
- **Tap targets are 44x44pt minimum.**
- **VoiceOver rotor** support for lists (budget categories read as "Groceries, budgeted £200, spent £156, available £44").

### 6.2 VoiceOver Design Patterns

- Combine related elements into single accessibility elements where appropriate: a budget row should read as one unit, not "Pizza emoji. Groceries. £200. £156. £44."
- Use `.accessibilityValue` for changing states (progress: "72 percent complete").
- Mark section headers with `.accessibilityAddTraits(.isHeader)`.
- Ensure swipe actions are discoverable via VoiceOver's Actions rotor.

### 6.3 Reduced Motion

When `accessibilityReduceMotion` is enabled:
- Replace all custom animations with crossfade or instant transitions.
- Disable confetti, counting number effects, and spring animations.
- Keep progress ring fills but make them instant rather than animated.
- Retain haptic feedback (it's tactile, not visual motion).

---

## 7. Component Patterns

### 7.1 Cards

Cards are used for elevated, self-contained pieces of information (account summaries, report charts, goal progress).

- Background: system grouped background
- Corner radius: 12pt
- Padding: 16pt internal
- Shadow: Raised level (`.shadow(color: .black.opacity(0.06), radius: 4, y: 2)`)
- **Do not nest cards.** If a card needs sub-sections, use dividers or spacing, not nested cards.

### 7.2 List Rows

Standard list rows follow a consistent anatomy:

```
[ Emoji/Icon ] [ Title            ] [ Amount   ]
               [ Subtitle/Detail  ] [ Metadata ]
```

- Title: `.headline` weight
- Subtitle: `.subheadline` + `.secondary` color
- Amount: `.headline` or `.title3` with `.monospacedDigit()` + semantic color
- Metadata: `.caption` + `.secondary` or `.tertiary` color
- Minimum row height: 44pt (system default)
- Chevron for navigable rows (system default for `NavigationLink`)

### 7.3 Section Headers

- Header text should be short and scannable — "Budget Accounts" not "Your Budget Accounts Listed Below".
- Collapsible headers use a leading disclosure chevron (`chevron.right` / `chevron.down`) at `.caption2.bold()` in `.secondary`.

**Summary headers** (used on the budget screen) extend the basic pattern with trailing aggregate columns:

```
[ ▸ ] [ HEADER NAME (uppercased) ] [ Budgeted column ] [ Available column ]
```

- Header name: `.headline` + `.secondary` + `.uppercased()`
- Column labels: `.caption2` + `.tertiary`, sitting above the value
- Column values: `.subheadline.bold()` + `.monospacedDigit()`, `.secondary` for budgeted, semantic colour for available
- Column widths: fixed (100pt budgeted, 88pt available) with `.minimumScaleFactor(0.5)` for overflow
- Background: `.secondarySystemBackground` to visually separate from child rows
- Row insets: 10pt vertical, 16pt horizontal
- Collapsing a header auto-saves any active keypad editing within that group

### 7.4 Status Pills

Status pills sit below the navigation area to communicate the screen's primary status. They are compact, tappable where actionable, and occupy minimal vertical space compared to full-width banners.

| Pill Type | Background | Text | Font | Corner Radius | Example |
|-----------|------------|------|------|---------------|---------|
| **Primary (positive)** | `.accentColor.opacity(0.15)` | `.accentColor` | `.subheadline.bold()` | 10pt | "To Budget: £500" |
| **Warning** | `.red.opacity(0.08)` | `.red.opacity(0.7)` | `.subheadline` | 10pt | "Overbudgeted by £50" |
| **Negative** | `.red.opacity(0.08)` | `.red.opacity(0.7)` | `.subheadline` | 10pt | "Overspent in 3 categories" |
| **Info** | `.accentColor.opacity(0.08)` | `.accentColor` | `.subheadline` | 10pt | Trial status, sync info |

**Tappable pills** (those that lead to a fix-it sheet or detail) include a trailing chevron (`chevron.right`) for affordance, with an invisible matching chevron on the leading side to keep text centred. Use `.buttonStyle(.plain)`.

**Layout:** Pills stack vertically with 8pt spacing. The primary pill spans full width; secondary pills sit side by side when both are present. Horizontal padding matches the screen edge inset (12–16pt).

**When to use pills vs. inline indicators:** Use a status pill for screen-level status that the user should notice immediately (budget health, overdue warnings). Use inline semantic colour for row-level status (a single overspent category's red available amount).

### 7.5 Action Sheets & Confirmation Dialogs

- Use **confirmation dialogs** (`.confirmationDialog`) for destructive actions: delete transaction, restore backup, remove family member.
- The destructive option should always be `.red` and listed last.
- Provide a clear, non-destructive cancel option.
- The title should describe the consequence: "Delete this transaction?" not "Are you sure?"

### 7.6 Empty States

Use `ContentUnavailableView` with:
- An SF Symbol that relates to the content type (e.g., `banknote` for transactions, `target` for goals)
- A short title: "No transactions yet"
- A one-line description: "Add your first transaction to start tracking"
- A call-to-action button when creation is possible from that screen

### 7.7 Inline Keypads

When a screen needs rapid numeric entry without leaving context (budget allocation, goal contributions), present a custom keypad as a `safeAreaInset(edge: .bottom)` rather than a sheet or system keyboard.

**Keypad layout:** 4×4 grid using `LazyVGrid` with flexible columns and 8pt spacing. Rows: digits 1–9, then dismiss / 0 / equals / done. Operators (+/−) and backspace occupy the right column.

**Key button styles:**

| Role | Font | Foreground | Background | Corner Radius | Min Height |
|------|------|-----------|------------|---------------|------------|
| **Digit** | `.title3` | `.primary` | `.systemFill` | 10pt | 48pt |
| **Operator** | `.title3` | `.accentColor` | `.accentColor.opacity(0.15)` | 10pt | 48pt |
| **Dismiss / Backspace** | `.title3` | `.secondary` | `.quaternarySystemFill` + `.separator` border | 10pt | 48pt |
| **Done** | `.title3.bold()` | `.white` | `.accentColor` | 10pt | 48pt |

**Presentation:** The keypad slides up from the bottom with a spring animation (response 0.35s, damping 0.85). When `accessibilityReduceMotion` is enabled, use a simple opacity crossfade instead. The keypad's background uses `.bar` material for translucency.

**Haptics:** Each key press triggers `.impact(flexibility: .rigid, intensity: 0.4)`. This is lightweight enough for rapid tapping without feeling heavy.

**Auto-save behaviour:** Changing focus to a different editable row auto-saves the current value and shifts the keypad context. Changing month or navigating away also auto-saves. Cancel reverts to the pre-edit value.

### 7.8 Action Bars

An action bar is a thin strip that sits directly above an inline keypad (or at the bottom of a scroll view) to provide contextual actions related to the current editing state.

- Background: `.bar` material (matches the keypad)
- Horizontal padding: 12pt, vertical: 8pt
- Buttons use `.subheadline.bold()` with `.accentColor` text on `.accentColor.opacity(0.15)` background, 8pt corner radius, 12pt horizontal / 6pt vertical padding
- Button widths are equalised using `onGeometryChange` so neither button dominates
- Actions are context-specific: on the budget screen, "Quick Fill" (opens a popover with historical suggestions) and "Details" (navigates to category detail)

---

## 8. Screen-Specific Guidelines

### 8.1 Budget Screen (Primary)

The budget screen is the heart of the app. It must answer three questions at a glance:
1. "How much can I still allocate?" (To Budget status pill)
2. "Am I overspending anywhere?" (Red available amounts + overspent pill)
3. "What's my overall budget health?" (Category list with header summaries)

**Layout (top to bottom):**
1. **Month selector** — Previous/next chevrons at edges, tappable month label with dropdown in centre. When not on the current month, a "Today" pill appears in the gap between the chevron and the month label to allow quick return. Horizontal swipe anywhere on the screen also navigates months.
2. **Status pills** — Compact tappable pills showing "To Budget" amount (always visible), plus "Overbudgeted" and/or "Overspent" pills when applicable. Tapping a warning pill opens a fix-it sheet.
3. **Category list** — Collapsible header groups with summary columns (Budgeted, Available). Each subcategory row shows name, budgeted amount, and available balance. Tapping a row activates the inline keypad.
4. **Inline keypad** — Appears as a `safeAreaInset(edge: .bottom)` with an action bar (Quick Fill, Details) above the key grid. The list resizes to accommodate the keypad; the focused row scrolls into view if needed.
5. **Toolbar** — Profile button (leading), "Budget" title (principal), add-transaction button and overflow menu (trailing). The overflow menu provides Auto-Fill Budget and Edit Categories.

**Inline editing behaviour:**
- Tapping a category row activates the keypad immediately (no navigation, no sheet)
- The action bar above the keypad offers Quick Fill (popover with last month, 12-month averages) and Details (navigates to category detail)
- Tapping a different row auto-saves the current value and shifts focus
- Changing month, collapsing a header group, or navigating away all auto-save
- Cancel reverts to the pre-edit value; Done confirms
- The "To Budget" pill updates live as allocations change
- Focused row gets `.accentColor.opacity(0.12)` background with `.selection` haptic

### 8.2 Transaction List

The transaction list must support rapid scanning. Users glance at dozens of rows to find what they need.

**Layout (top to bottom):**
1. **Month selector** — Identical to the budget screen: previous/next chevrons, tappable month label with picker, "Today" pill for quick return. Horizontal swipe also navigates months.
2. **Filter chip** — When an account filter is active, a dismissible accent-coloured pill appears below the month selector showing the account name with an × to clear.
3. **Search bar** — Toggled from the filter menu. A custom inline search bar appears below the month selector (and filter chip if present) with payee/memo/category search.
4. **Day-grouped list** — Transactions within the selected month, grouped by calendar day (most recent first). Each date section header shows the weekday and full date.
5. **Toolbar** — Profile button (leading), "Transactions" title (principal), add-transaction button and filter menu (trailing). The filter menu provides search toggle and account filtering. The filter icon fills when any filter or search is active.

**Row design:** Payee name and amount are the two most important pieces — they should be visually dominant. Category and account are supporting context.

**Filtering:** Account filtering and search live in a toolbar filter menu (icon: `line.3.horizontal.decrease.circle`). The icon uses its filled variant when a filter or search is active. Active account filters show as a dismissible chip below the month selector for clear visibility and one-tap dismissal.

### 8.3 Goals Screen

Goals are emotional — they represent aspirations. The design should reflect that:

- Progress rings should be large enough to feel satisfying (not tiny indicators)
- Use the goal's emoji prominently
- Show projected completion date to maintain motivation
- Completed goals should feel celebratory (checkmark, muted color to distinguish from active)

### 8.4 Reports Screen

Reports must prioritize clarity over density:

- One chart per viewport (scrollable). Don't cram multiple charts into a single screen.
- Charts should be tappable/interactive — selecting a bar or segment shows its value.
- Use consistent axis labeling (months abbreviated, amounts with currency symbol).
- Default to the most useful time range (3 or 6 months) with easy range adjustment.

---

## 9. Writing & Tone

### 9.1 Voice Principles

- **Clear over clever.** "Add Transaction" not "Log a Spend." "Delete" not "Remove Forever."
- **Active voice.** "You budgeted £500 for groceries" not "£500 was budgeted for groceries."
- **Present tense.** "Your goal is 72% complete" not "Your goal has been 72% completed."
- **Brief.** Button labels: 1-3 words. Descriptions: 1 sentence. Error messages: 2 sentences maximum.

### 9.2 Terminology Consistency

Use these terms consistently throughout the app:

| Correct Term | Not This |
|-------------|----------|
| Transaction | Entry, Record, Item |
| Category | Envelope, Bucket, Pot |
| Budget (verb) | Allocate, Assign, Plan |
| Available | Remaining, Left, Balance |
| Overspent | Over budget, Negative, In the red |
| Account | Wallet, Fund, Source |
| Goal | Target, Savings pot |
| Transfer | Move money |
| Recurring | Repeating, Scheduled, Auto |
| Cleared | Reconciled, Confirmed |

### 9.3 Error & Empty State Copy

- **Errors:** State the problem, then the solution. "Couldn't save your transaction. Check your connection and try again."
- **Empty states:** Be encouraging. "No goals yet — what are you saving for?" not "No data to display."
- **Destructive confirmations:** State the consequence. "This will permanently delete all 24 transactions in this account." not "Are you sure?"

---

## 10. Visual Consistency & Refinement

### 10.1 The Squint Test

Blur your eyes and look at any screen. You should still be able to identify: (1) the most important number, (2) the primary content area, and (3) where to take action. If the visual hierarchy collapses when blurred, the weights, sizes, and spacing need adjustment. This is the simplest proxy for whether a screen reads well at a glance.

### 10.2 Consistency Beats Novelty

Every screen in the app should feel like it belongs to the same family. This means:

- **Same row structure everywhere.** A row on the budget screen, transaction list, and goal list should share the same anatomy: leading visual, title + subtitle, trailing value. The specific content changes; the skeleton does not.
- **Same interaction patterns everywhere.** Pick one pattern per interaction type and use it across the entire app. On the budget screen, tapping a category row activates inline editing (the keypad); navigating to a category's detail pushes within the same `NavigationStack`. Other screens should follow the same conventions: inline editing stays in-place, detail views push, and creation/editing of discrete items uses sheets.
- **Same empty state treatment everywhere.** Every empty list uses `ContentUnavailableView` with the same structure (icon, title, description, optional action). No screen gets a custom empty layout.
- **Same status pill treatment everywhere.** The "To Budget" pill, "Overspent" warning, and "Trial expires" info all use the same pill component with different semantic colors. They should not look like three different UI elements.

### 10.3 Optical Alignment

Numbers, icons, and text have different visual weights even when they're technically the same size. Always check alignment visually, not just in code:

- Currency symbols are lighter than digits — they may need to be the same font size but will look optically smaller. This is fine; don't enlarge them.
- Emojis in leading position should be vertically centered with the first line of text, not the full row height.
- Right-aligned numbers in a column should align on the decimal point, which `.monospacedDigit()` achieves automatically.

### 10.4 Whitespace as a Feature

Resist the urge to fill space. A screen with breathing room feels premium and confident. A screen crammed with data feels anxious. When in doubt, add more whitespace, not more content. This is especially true for:

- The area above and below hero numbers (the "To Budget" amount, account totals)
- The space between section groups in lists
- The padding inside cards and status pills
- The gap between the last list item and the bottom of the screen

### 10.5 Polish Signals

Small details that separate a good app from a great one:

- Amounts that animate between values rather than snapping (with reduced motion respected)
- Buttons that have a brief highlight state rather than appearing to do nothing between tap and result
- Lists that show the content structure (skeleton) before data loads, rather than a spinner or blank screen
- Sheet presentations that feel physical — the system spring is already good; never override it with a linear animation
- Consistent alignment across screens — if the leading edge of content is 16pt from the screen edge on one screen, it should be 16pt on every screen

---

## 11. Platform Conventions

### 11.1 iOS Design Conventions to Follow

- Use standard navigation bar placement (title centered or large title left-aligned).
- Use standard toolbar placement (bottom of screen for primary actions).
- Follow the system back button convention (never create a custom back button).
- Use `.sheet` for focused tasks, `.fullScreenCover` for onboarding/immersive flows.
- Use `TabView` with `.sidebarAdaptable` for iPad sidebar adaptation.
- Use `.confirmationDialog` not custom alert views for action sheets.
- Respect the safe area — never place content under the home indicator or notch.

### 11.2 iOS Conventions to Intentionally Break

- None. FamFin follows iOS conventions faithfully. Users should feel at home immediately. Novelty in a finance app reduces trust.

---

## 12. Performance Perception

### 12.1 Perceived Speed

- **Optimistic UI:** When a user saves a transaction, update the local list immediately. Don't wait for SwiftData to persist.
- **Skeleton loading:** Show the structure of content before it loads. A shimmer of 5 category rows is better than a spinner.
- **Pre-load adjacent screens:** When the user is on Budget, pre-fetch data needed for Transactions.
- **Lazy loading for lists:** Use `LazyVStack` within `ScrollView` or standard `List` for transaction history. Never load 10,000 transactions into memory at once.

### 12.2 Actual Speed

- Minimize view body recomputation. Use `@Observable` correctly so views only re-render when their specific dependencies change.
- Batch SwiftData operations (bulk imports, recurring transaction generation).
- Use background contexts for heavy operations (import, export, report calculation).

---

## 13. Design Review Checklist

Before shipping any new view or feature, verify:

**Simplicity & Elegance**
- [ ] This feature cannot be achieved by improving an existing screen instead
- [ ] There is exactly one workflow for this task (multiple entry points are fine; multiple different experiences are not)
- [ ] Every element on screen has a clear purpose — nothing is decorative filler
- [ ] No new settings were added that could have been smart defaults
- [ ] Row structure, interaction patterns, and empty states match the rest of the app
- [ ] The screen passes the squint test (hierarchy is clear when blurred)

**Quality & Correctness**
- [ ] Works in both light and dark mode
- [ ] Works at all Dynamic Type sizes (xSmall through accessibility5)
- [ ] All colors meet WCAG AA contrast ratios
- [ ] VoiceOver reads all content in logical order
- [ ] All interactive elements have 44x44pt minimum tap targets
- [ ] Loading, empty, content, and error states are all designed
- [ ] Animations respect `accessibilityReduceMotion`
- [ ] Haptics are appropriate and consistent with the haptic language
- [ ] Numbers use `.monospacedDigit()` and proper currency formatting
- [ ] No force unwraps or assumptions about data presence

**Structure & Navigation**
- [ ] Navigation depth does not exceed 3 levels from tab
- [ ] The "Where does this live?" test has a clear, single answer
- [ ] Sheet dismissal has explicit Save/Cancel (no auto-dismiss)
- [ ] Destructive actions have confirmation dialogs

**Craft**
- [ ] Copy follows the terminology guide and voice principles
- [ ] Spacing uses the defined scale (4/8/12/16/24/32)
- [ ] Corner radii match the element type (12/10/8/6)
- [ ] Leading edge alignment is consistent with adjacent screens
- [ ] Whitespace around hero elements feels generous, not cramped

---

*These principles are a living document. As the app evolves, update them to reflect new patterns and lessons learned. Consistency is more important than any single rule — when in doubt, match what already exists.*
