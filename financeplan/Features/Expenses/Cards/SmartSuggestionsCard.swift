import Charts
import SwiftUI
import StockPlanShared
import Factory

struct SmartSuggestionsCard: View {
  let suggestion: ReportSuggestionResponse?
  let isLoading: Bool
  let isUnavailable: Bool
  let onDismiss: (ReportSuggestionResponse) -> Void

  @State private var selectedSuggestion: ReportSuggestionResponse?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        Image(systemName: "lightbulb.fill")
          .foregroundStyle(.yellow)
          .font(.title3)
        Text("Smart Suggestions")
          .font(.headline)
      }

      if isLoading {
        VStack(alignment: .leading, spacing: 12) {
          Text("Loading suggestion")
            .font(.subheadline)
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.18))
            .frame(height: 12)
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.18))
            .frame(height: 12)
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.14))
            .frame(height: 42)
        }
        .redacted(reason: .placeholder)
        .shimmer()
      } else if let suggestion {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Text(suggestion.severity.rawValue.capitalized)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(severityColor(suggestion.severity), in: Capsule())
            Text(suggestion.monthStart)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Text(suggestion.title)
            .font(.headline)
            .foregroundStyle(.primary)

          Text(suggestion.message)
            .font(.subheadline)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)

          Text("Potential savings: \(suggestion.recommendedSavings.currency)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(severityColor(suggestion.severity))
        }
        .transition(.asymmetric(insertion: .scale(scale: 0.98).combined(with: .opacity), removal: .opacity))

        HStack(spacing: 12) {
          Button {
            selectedSuggestion = suggestion
          } label: {
            Text("View Details")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color.white.opacity(0.1))
              .clipShape(.rect(cornerRadius: 12))
              .foregroundStyle(.white)
          }

          Button {
            onDismiss(suggestion)
          } label: {
            Text("Dismiss")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color.white.opacity(0.1))
              .clipShape(.rect(cornerRadius: 12))
              .foregroundStyle(.white)
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text(isUnavailable ? "Unavailable" : "No suggestions right now")
            .font(.subheadline.weight(.semibold))
          Text(isUnavailable ? "-- / no data" : "You're all caught up for this period.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(20)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 20))
    .animation(.easeOut(duration: 0.25), value: isLoading)
    .sheet(item: $selectedSuggestion) { suggestion in
      SuggestionDetailSheet(suggestion: suggestion)
    }
  }

  private func severityColor(_ severity: ReportSuggestionSeverity) -> Color {
    switch severity {
    case .high:
      return .red
    case .medium:
      return .orange
    case .low:
      return .green
    }
  }
}

struct SuggestionDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  let suggestion: ReportSuggestionResponse

  var body: some View {
    NavigationStack {
      List {
        Section("Summary") {
          LabeledContent("Category", value: suggestion.category.rawValue)
          LabeledContent("Month", value: suggestion.monthStart)
          LabeledContent("Recommended savings", value: suggestion.recommendedSavings.currency)
        }
        if suggestion.detailPayload.isEmpty == false {
          Section("Details") {
            ForEach(suggestion.detailPayload.keys.sorted(), id: \.self) { key in
              LabeledContent(key, value: suggestion.detailPayload[key] ?? "")
            }
          }
        }
      }
      .navigationTitle(suggestion.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

struct ExpensesByCategoryCard: View {
  let monthTitle: String
  let activities: [BudgetActivity]
  let summaries: [PillarPlanningSummary]
  let onEdit: (BudgetActivity) -> Void
  let onDelete: (BudgetActivity) -> Void

  @Environment(\.colorScheme) private var colorScheme

  private var groupedActivities: [(BudgetPillar, [BudgetActivity])] {
    let grouped = Dictionary(grouping: activities, by: { $0.pillar })
    return BudgetPillar.sortedForDisplay(grouped.keys).compactMap { pillar in
      guard let items = grouped[pillar], !items.isEmpty else { return nil }
      return (pillar, items.sorted { $0.occurredOn > $1.occurredOn })
    }
  }

  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Where your expenses go")
            .typography(.label, weight: .semibold)
          Spacer()
          Text(monthTitle)
            .typography(.small)
            .foregroundStyle(.secondary)
        }

        if activities.isEmpty {
          ContentUnavailableView {
            Label("No expenses logged", systemImage: "cart")
          } description: {
            Text("Your spending summary will appear here once you record your first expense")
          }
          .padding(.vertical, 8)
        } else {
          // Summary Chart
          if summaries.contains(where: { $0.actualAmount > 0 }) {
              Chart(summaries.filter { $0.actualAmount > 0 }) { summary in
                  SectorMark(
                      angle: .value("Amount", summary.actualAmount),
                      innerRadius: .ratio(0.65),
                      outerRadius: .ratio(1.0),
                      angularInset: 2.0
                  )
                  .foregroundStyle(summary.pillar.color(for: colorScheme))
              }
              .frame(height: 180)
              .padding(.vertical, 8)
              .transition(.opacity.combined(with: .scale))
          }

          // Structured Tree List (As requested: 🏠 PILLAR ... Total / │ Item ... Amount / │ Split)
          ForEach(groupedActivities, id: \.0) { pillar, pillarActivities in
            VStack(alignment: .leading, spacing: 0) {
              HStack(spacing: 8) {
                Image(systemName: pillar.symbol)
                  .typography(.small)
                  .foregroundStyle(pillar.color(for: colorScheme))
                  .frame(width: 20)

                Text(pillar.title.uppercased())
                  .typography(.nano, weight: .bold)
                  .foregroundStyle(.primary)
                  .tracking(0.5)

                Spacer()

                let total = pillarActivities.reduce(0) { $0 + $1.amount }
                Text(total.currency)
                  .typography(.nano, weight: .bold)
                  .foregroundStyle(.primary)
              }
              .padding(.bottom, 12)

              ForEach(pillarActivities) { activity in
                VStack(alignment: .leading, spacing: 0) {
                  HStack(alignment: .top, spacing: 12) {
                    Text("│")
                      .font(.system(size: 16, weight: .regular, design: .monospaced))
                      .foregroundStyle(pillar.color(for: colorScheme).opacity(0.4))
                      .frame(width: 20)

                    VStack(alignment: .leading, spacing: 4) {
                      HStack {
                        Text(activity.title)
                          .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(activity.amount.currency)
                          .font(.subheadline.weight(.semibold))
                      }

                      Text(activity.splitMode == .shared ? "Shared • \(Int(activity.userSharePercent))% yours" : "Personal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Menu {
                      Button("Edit", systemImage: "pencil") { onEdit(activity) }
                      Button("Delete", systemImage: "trash", role: .destructive) { onDelete(activity) }
                    } label: {
                      Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                  }
                  .padding(.vertical, 6)

                  if activity.id != pillarActivities.last?.id {
                      Text("│")
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .foregroundStyle(pillar.color(for: colorScheme).opacity(0.4))
                        .frame(width: 20)
                        .padding(.vertical, 4)
                  }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button(role: .destructive) { onDelete(activity) } label: {
                    Label("Delete", systemImage: "trash")
                  }
                  Button { onEdit(activity) } label: {
                    Label("Edit", systemImage: "pencil")
                  }
                  .tint(.blue)
                }
              }
            }
            .padding(.vertical, 8)

            if pillar != groupedActivities.last?.0 {
              Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)
            }
          }
        }
      }
    }
  }
}

// MARK: - Recurring Templates Manager

struct RecurringTemplatesManagerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  let templates: [RecurringTemplateResponse]
  let availableCategories: [ExpenseCategoryResponse]
  let availablePillars: [BudgetPillar]
  let onSave: (RecurringTemplateRequest, String?) -> Void
  let onDelete: (String) -> Void

  @State private var editingTemplate: RecurringTemplateResponse?
  @State private var isAddingNew = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(templates) { template in
          Button { editingTemplate = template } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(template.title).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                  Text(template.pillar.title).font(.caption).foregroundStyle(.secondary)
                  Text("·").foregroundStyle(.secondary)
                  Text(template.frequency == .monthly ? "Monthly" : "Weekly")
                    .font(.caption)
                    .foregroundStyle(template.pillar.color(for: colorScheme))
                }
              }
              Spacer()
              Text(template.amount.currency).font(.subheadline.weight(.semibold))
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete(template.id) } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
      }
      .navigationTitle("Recurring Templates")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Add", systemImage: "plus") { isAddingNew = true }
        }
      }
      .sheet(item: $editingTemplate) { template in
        RecurringTemplateEditorSheet(
          template: template,
          availablePillars: availablePillars,
          availableCategories: availableCategories,
          onSave: { req in onSave(req, template.id) }
        )
      }
      .sheet(isPresented: $isAddingNew) {
        RecurringTemplateEditorSheet(
          template: nil,
          availablePillars: availablePillars,
          availableCategories: availableCategories,
          onSave: { req in onSave(req, nil) }
        )
      }
    }
  }
}

struct RecurringTemplateEditorSheet: View {
  @Environment(\.dismiss) private var dismiss

  let template: RecurringTemplateResponse?
  let availablePillars: [BudgetPillar]
  let availableCategories: [ExpenseCategoryResponse]
  let onSave: (RecurringTemplateRequest) -> Void

  @State private var title: String
  @State private var amountText: String
  @State private var pillar: BudgetPillar
  @State private var categoryId: String?
  @State private var frequency: RecurringFrequency
  @State private var splitMode: ExpenseSplitMode
  @State private var userSharePercent: Double

  init(
    template: RecurringTemplateResponse?,
    availablePillars: [BudgetPillar],
    availableCategories: [ExpenseCategoryResponse],
    onSave: @escaping (RecurringTemplateRequest) -> Void
  ) {
    self.template = template
    self.availablePillars = availablePillars.isEmpty ? BudgetPillar.standardPillars : availablePillars
    self.availableCategories = availableCategories
    self.onSave = onSave
    _title = State(initialValue: template?.title ?? "")
    _amountText = State(initialValue: template.map { String($0.amount) } ?? "")
    _pillar = State(initialValue: template?.pillar ?? .fundamentals)
    _categoryId = State(initialValue: template?.categoryId)
    _frequency = State(initialValue: template?.frequency ?? .monthly)
    _splitMode = State(initialValue: template?.splitMode ?? .personal)
    _userSharePercent = State(initialValue: template?.userSharePercent ?? 100)
  }

  private var filteredCategories: [ExpenseCategoryResponse] {
    availableCategories.filter { $0.pillar == nil || $0.pillar == pillar }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Details") {
          TextField("Title", text: $title).textInputAutocapitalization(.words)
          TextField("Amount", text: $amountText).keyboardType(.decimalPad)
        }
        Section("Category") {
          Picker("Pillar", selection: $pillar) {
            ForEach(availablePillars, id: \.self) { p in
              Text(p.title).tag(p)
            }
          }
          if !filteredCategories.isEmpty {
            Picker("Category", selection: $categoryId) {
              Text("None").tag(String?.none)
              ForEach(filteredCategories) { cat in
                Text(cat.name).tag(Optional(cat.id))
              }
            }
          }
          Picker("Frequency", selection: $frequency) {
            Text("Monthly").tag(RecurringFrequency.monthly)
            Text("Weekly").tag(RecurringFrequency.weekly)
          }
        }
        Section("Split") {
          Picker("Mode", selection: $splitMode) {
            Text("Personal").tag(ExpenseSplitMode.personal)
            Text("Shared").tag(ExpenseSplitMode.shared)
          }
          if splitMode == .shared {
            HStack {
              Text("My share")
              Spacer()
              Text("\(Int(userSharePercent.rounded()))%").foregroundStyle(.secondary)
            }
            Slider(value: $userSharePercent, in: 0...100, step: 1)
          }
        }
      }
      .navigationTitle(template == nil ? "New Recurring" : "Edit Recurring")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            guard let amount = MoneyInputParser.parse(amountText), !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            onSave(RecurringTemplateRequest(
              title: title.trimmingCharacters(in: .whitespacesAndNewlines),
              amount: amount,
              pillar: pillar,
              categoryId: categoryId,
              frequency: frequency,
              splitMode: splitMode,
              userSharePercent: splitMode == .personal ? 100 : userSharePercent
            ))
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || MoneyInputParser.parse(amountText) == nil)
        }
      }
      .onChange(of: pillar) { _, _ in categoryId = nil }
    }
  }
}

struct ExpensesSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 120)
                        .shimmer()
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 20)
        }
    }
}
