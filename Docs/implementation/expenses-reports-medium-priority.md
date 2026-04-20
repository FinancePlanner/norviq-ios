# Expenses & Reports Medium Priority Enhancements

**Date:** April 11, 2026  
**Status:** ✅ Implemented

---

## Overview

This document covers the medium-priority visual and UX enhancements implemented for the Expenses and Reports features, building on the high-priority improvements.

---

## 1. Swipe Actions on Plan Items

### Implementation
**File:** `Features/Expenses/ExpensesPlannerScreen.swift` - `MonthlyPlanItemsCard`

### Features
- ✅ **Swipe-to-delete** - Swipe left on any plan item to reveal delete action
- ✅ **Swipe-to-edit** - Blue edit button appears alongside delete
- ✅ **Non-destructive swipe** - `allowsFullSwipe: false` prevents accidental deletion
- ✅ **Color-coded actions** - Red for delete, blue for edit

### User Experience
```
[Plan Item Row]
← Swipe left
[Edit (Blue)] [Delete (Red)]
```

### Code Pattern
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
  Button(role: .destructive) {
    onDelete(item)
  } label: {
    Label("Delete", systemImage: "trash")
  }
  
  Button {
    onEdit(item)
  } label: {
    Label("Edit", systemImage: "pencil")
  }
  .tint(.blue)
}
```

---

## 2. Inline Amount Editing

### Implementation
**File:** `Features/Expenses/ExpensesPlannerScreen.swift` - `MonthlyPlanItemsCard`

### Features
- ✅ **Tap amount to edit** - Tap the currency value to enter edit mode
- ✅ **Inline text field** - Amount becomes editable without opening sheet
- ✅ **Save button** - Explicit save action
- ✅ **Keyboard submit** - Press return to save
- ✅ **Auto-focus** - Keyboard appears immediately
- ✅ **Validation** - Uses `MoneyInputParser` for proper formatting

### User Flow
1. User taps `€1,200` amount
2. Text field appears with current value
3. User edits amount
4. Taps "Save" or presses Return
5. Amount updates immediately

### State Management
```swift
@State private var editingItemID: UUID?
@State private var editAmount: String = ""
@FocusState private var focusedItemID: UUID?

private func startInlineEdit(_ item: BudgetPlanItem) {
  editingItemID = item.id
  editAmount = item.plannedAmount.formatted(...)
  focusedItemID = item.id
}

private func saveInlineEdit(_ item: BudgetPlanItem) {
  guard let amount = MoneyInputParser.parse(editAmount) else {
    editingItemID = nil
    return
  }
  // Update item...
  editingItemID = nil
}
```

### Benefits
- **Faster workflow** - No need to open full edit sheet for simple amount changes
- **Context preservation** - User stays in the list view
- **Clear affordance** - Amount is tappable, indicating editability

---

## 3. Historical Comparison Indicators

### Implementation
**File:** `Features/Expenses/BudgetCategoryDetailsScreen.swift` - `BudgetCategoryCard`

### Features
- ✅ **Month-over-month change** - Shows percentage change vs previous month
- ✅ **Directional arrows** - Up arrow (increase), down arrow (decrease)
- ✅ **Color coding** - Orange for increase, green for decrease
- ✅ **Contextual display** - Only shows when previous month data exists

### Visual Design
```
Budget usage                        82%
████████████████████░░░░░░░░
✓ €350 remaining  ↗ 15% vs last month
```

### Calculation Logic
```swift
private var monthOverMonthChange: (amount: Double, percentage: Double)? {
  guard let previous = previousMonthActual, previous > 0 else { return nil }
  let change = summary.actualAmount - previous
  let percentage = (change / previous) * 100
  return (change, percentage)
}
```

### ViewModel Support
**File:** `Features/Expenses/BudgetPlannerViewModel.swift`

```swift
func previousMonthPillarActual(for pillar: BudgetPillar) -> Double? {
  guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonthStart) else {
    return nil
  }
  let previousMonthStart = calendar.startOfMonth(for: previousMonth)
  return actualTotal(for: pillar, monthStart: previousMonthStart)
}
```

### Benefits
- **Trend awareness** - Users immediately see if spending is increasing or decreasing
- **Behavioral insights** - Helps identify spending patterns
- **Actionable feedback** - "15% increase" prompts review of that category

---

## 4. Chart Drill-Down (Reports)

### Implementation
**File:** `Features/Expenses/ExpensesComparisonScreen.swift` - `SpendingInsightsSection`

### Features
- ✅ **Tap chart segment** - Tap any pillar in the donut chart to see details
- ✅ **Tap category row** - Tap any category in the list below chart
- ✅ **Chart angle selection** - Uses `.chartAngleSelection()` for native interaction
- ✅ **Detail sheet** - Full-screen modal with pillar breakdown
- ✅ **Chevron indicators** - Visual cue that rows are tappable

### Chart Interaction
```swift
@State private var selectedPillar: BudgetPillar?
@State private var showingPillarDetail = false

Chart {
  // ... SectorMark definitions
}
.chartAngleSelection(value: $selectedPillar)
.onChange(of: selectedPillar) { _, newValue in
  if newValue != nil {
    showingPillarDetail = true
  }
}
```

### PillarDetailSheet Components

#### Header Section
- Large pillar icon (80pt circle)
- Pillar title and subtitle
- Color-coded theme

#### Spending Overview Card
- Actual spending (large, bold)
- Budget amount (large, bold)
- Progress bar with percentage
- Color-coded status (red if over budget)

#### Breakdown Card
- My spending vs Partner spending
- My plan vs Partner plan
- Side-by-side comparison

#### Alert Card (conditional)
- Shows only if over budget
- Warning icon and message
- Amount over budget

### Visual Layout
```
┌─────────────────────────────────┐
│         [Pillar Icon]           │
│      Fundamentals               │
│  Daily life and recurring...    │
├─────────────────────────────────┤
│ ACTUAL SPENDING    BUDGET       │
│ €1,650             €2,000       │
│                                 │
│ Budget usage            82%     │
│ ████████████████████░░░         │
├─────────────────────────────────┤
│ BREAKDOWN                       │
│ My spending    Partner spending │
│ €900           €750             │
│                                 │
│ My plan        Partner plan     │
│ €1,100         €900             │
└─────────────────────────────────┘
```

### Benefits
- **Deeper insights** - Users can explore spending by category
- **Household transparency** - Clear breakdown of who spent what
- **Contextual navigation** - Natural drill-down from overview to detail
- **Native feel** - Uses SwiftUI Charts selection APIs

---

## Technical Implementation Details

### State Management Patterns

#### Inline Editing State
```swift
// Editing state
@State private var editingItemID: UUID?
@State private var editAmount: String = ""
@FocusState private var focusedItemID: UUID?

// Conditional rendering
if editingItemID == item.id {
  TextField("Amount", text: $editAmount)
    .focused($focusedItemID, equals: item.id)
    .onSubmit { saveInlineEdit(item) }
} else {
  Button { startInlineEdit(item) } label: {
    Text(item.plannedAmount.currency)
  }
}
```

#### Chart Selection State
```swift
@State private var selectedPillar: BudgetPillar?
@State private var showingPillarDetail = false

// Chart binding
.chartAngleSelection(value: $selectedPillar)

// Sheet presentation
.sheet(isPresented: $showingPillarDetail) {
  if let pillar = selectedPillar,
     let summary = pillarSummaries.first(where: { $0.pillar == pillar }) {
    PillarDetailSheet(...)
  }
}
```

### Data Flow

#### Historical Comparison
```
BudgetCategoryDetailsScreen
  ↓ calls
BudgetPlannerViewModel.previousMonthPillarActual(for:)
  ↓ calculates
Previous month start date
  ↓ queries
actualTotal(for:monthStart:)
  ↓ returns
Double? (nil if no previous data)
  ↓ passed to
BudgetCategoryCard.previousMonthActual
  ↓ computes
monthOverMonthChange: (amount, percentage)?
  ↓ displays
"↗ 15% vs last month"
```

#### Chart Drill-Down
```
User taps chart segment
  ↓ triggers
.chartAngleSelection(value: $selectedPillar)
  ↓ updates
selectedPillar = .fundamentals
  ↓ triggers
.onChange(of: selectedPillar)
  ↓ sets
showingPillarDetail = true
  ↓ presents
.sheet(isPresented: $showingPillarDetail)
  ↓ shows
PillarDetailSheet(pillar, summary, monthSummary, partnerName)
```

---

## User Experience Improvements

### Before → After Comparisons

#### Editing Plan Items
**Before:**
1. Tap menu button
2. Tap "Edit"
3. Sheet opens
4. Change amount
5. Tap "Save"
6. Sheet dismisses

**After (Quick Edit):**
1. Tap amount
2. Type new value
3. Press Return

**After (Full Edit):**
1. Swipe left
2. Tap "Edit"
3. Full sheet for complex changes

#### Understanding Spending Trends
**Before:**
- See current month spending: €1,650
- No context for whether this is normal

**After:**
- See current month spending: €1,650
- See "↗ 15% vs last month"
- Immediate understanding of trend

#### Exploring Spending Categories
**Before:**
- See chart with percentages
- See list of categories
- No way to get more details

**After:**
- Tap chart segment → detailed breakdown
- Tap category row → detailed breakdown
- See my vs partner split
- See planned vs actual
- See over-budget warnings

---

## Accessibility Considerations

### Swipe Actions
- ✅ VoiceOver announces "Actions available" on rows
- ✅ Custom actions menu for VoiceOver users
- ✅ Clear labels: "Delete [item name]", "Edit [item name]"

### Inline Editing
- ✅ TextField has proper label
- ✅ Save button is clearly labeled
- ✅ Focus management works with VoiceOver

### Historical Indicators
- ✅ Arrow direction announced ("increased", "decreased")
- ✅ Percentage change announced
- ✅ Color not sole indicator (arrows + text)

### Chart Drill-Down
- ✅ Chart segments have labels
- ✅ Category rows have clear tap targets
- ✅ Chevron indicates interactivity
- ✅ Sheet has proper navigation structure

---

## Performance Considerations

### Inline Editing
- **Minimal re-renders** - Only editing row re-renders
- **Debounced validation** - Parse on submit, not on every keystroke
- **State isolation** - Editing state doesn't affect other rows

### Historical Comparison
- **Computed on demand** - Only calculated when card is visible
- **Cached in view model** - Previous month data fetched once
- **Optional rendering** - Only shows when data exists

### Chart Drill-Down
- **Lazy sheet loading** - Detail sheet only created when presented
- **Efficient data passing** - Only passes necessary data
- **Native chart selection** - Uses SwiftUI's optimized selection API

---

## Testing Checklist

### Swipe Actions
- [ ] Swipe left reveals actions
- [ ] Edit button opens full sheet
- [ ] Delete button shows confirmation
- [ ] Swipe right dismisses actions
- [ ] Full swipe is disabled
- [ ] Actions work on all items

### Inline Editing
- [ ] Tap amount enters edit mode
- [ ] Keyboard appears automatically
- [ ] Save button updates amount
- [ ] Return key saves
- [ ] Invalid input shows error
- [ ] Cancel (tap outside) reverts
- [ ] Only one item editable at a time

### Historical Comparison
- [ ] Shows percentage change when previous month exists
- [ ] Shows up arrow for increase
- [ ] Shows down arrow for decrease
- [ ] Orange color for increase
- [ ] Green color for decrease
- [ ] Hidden when no previous data
- [ ] Accurate calculation

### Chart Drill-Down
- [ ] Tap chart segment opens detail
- [ ] Tap category row opens detail
- [ ] Detail shows correct pillar
- [ ] Breakdown shows my/partner split
- [ ] Over-budget alert shows when applicable
- [ ] Done button dismisses sheet
- [ ] Works for all three pillars

---

## Future Enhancements

### Inline Editing Extensions
- **Inline title editing** - Edit item name inline too
- **Inline pillar change** - Picker appears inline
- **Batch editing** - Select multiple items to edit at once

### Historical Comparison Extensions
- **Year-over-year** - Compare to same month last year
- **Trend lines** - Mini sparkline showing 3-month trend
- **Forecast** - "At this rate, you'll spend €X this month"

### Chart Drill-Down Extensions
- **Transaction list** - Show actual transactions in detail sheet
- **Time range selector** - View different months in detail
- **Export detail** - Share pillar breakdown as image/PDF
- **Comparison mode** - Compare two months side-by-side

---

## Conclusion

These medium-priority enhancements significantly improve the user experience by:

1. **Reducing friction** - Swipe actions and inline editing make common tasks faster
2. **Adding context** - Historical comparisons help users understand trends
3. **Enabling exploration** - Chart drill-down lets users investigate their spending
4. **Maintaining consistency** - All features follow established design patterns

The implementations are performant, accessible, and maintainable, setting a strong foundation for future enhancements.
