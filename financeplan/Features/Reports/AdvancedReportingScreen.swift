import Factory
import StockPlanShared
import SwiftUI

struct AdvancedReportingScreen: View {
  @Environment(\.openURL) private var openURL
  @InjectedObservable(\.billingManager) private var billingManager
  @State private var model = AdvancedReportingViewModel()
  @State private var isBuildingTemplate = false
  @State private var scheduleTemplate: ReportTemplate?
  @State private var isPaywallPresented = false

  var body: some View {
    List {
      if !billingManager.isPro {
        Section {
          ContentUnavailableView(
            "Reporting Center is read-only",
            systemImage: "doc.richtext",
            description: Text(
              "Existing reports stay available. Upgrade to build, schedule, or generate new PDF and Excel reports."
            )
          )
          Button("Upgrade to Pro") { isPaywallPresented = true }
        }
      }

      Section("Templates") {
        if model.templates.isEmpty {
          Text("No report templates yet").foregroundStyle(.secondary)
        }
        ForEach(model.templates) { template in
          VStack(alignment: .leading, spacing: 8) {
            Text(template.input.name).font(.headline)
            Text("\(template.input.blocks.count) sections · Revision \(template.revision)")
              .font(.caption).foregroundStyle(.secondary)
            HStack {
              Button("Generate") {
                guard billingManager.isPro else { isPaywallPresented = true; return }
                Task { _ = await model.generate(template: template, formats: [.pdf, .xlsx]) }
              }
              .buttonStyle(.borderedProminent)
              Button("Schedule") {
                guard billingManager.isPro else { isPaywallPresented = true; return }
                scheduleTemplate = template
              }
              .buttonStyle(.bordered)
            }
          }
          .padding(.vertical, 4)
        }
      }

      Section("Schedules") {
        if model.schedules.isEmpty {
          Text("No scheduled deliveries").foregroundStyle(.secondary)
        }
        ForEach(model.schedules) { schedule in
          ReportScheduleRow(schedule: schedule)
        }
      }

      Section("Report history") {
        if model.runs.isEmpty {
          Text("No generated reports").foregroundStyle(.secondary)
        }
        ForEach(model.runs) { run in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(run.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
              Spacer()
              Text(run.createdAt).font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(run.artifacts) { artifact in
              Button {
                Task {
                  if let url = await model.downloadURL(artifact: artifact) {
                    openURL(url)
                  }
                }
              } label: {
                Label(artifact.filename, systemImage: artifact.format == .pdf ? "doc.richtext" : "tablecells")
              }
            }
            if let failure = run.failureReason {
              Text(failure).font(.footnote).foregroundStyle(.red)
            }
          }
          .padding(.vertical, 4)
        }
      }
    }
    .navigationTitle("Reporting Center")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("New template", systemImage: "plus") {
          if billingManager.isPro {
            isBuildingTemplate = true
          } else {
            isPaywallPresented = true
          }
        }.labelStyle(.iconOnly)
      }
    }
    .overlay {
      if model.isLoading, model.templates.isEmpty {
        ProgressView()
      }
    }
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $isBuildingTemplate) { ReportTemplateBuilderSheet(model: model) }
    .sheet(item: $scheduleTemplate) { ReportScheduleSheet(template: $0, model: model) }
    .sheet(isPresented: $isPaywallPresented) { PaywallView(billingManager: billingManager) }
    .alert("Reporting request failed", isPresented: errorBinding) {
      Button("OK") { model.errorMessage = nil }
    } message: { Text(model.errorMessage ?? "Please try again.") }
  }

  private var errorBinding: Binding<Bool> {
    Binding(get: { model.errorMessage != nil }, set: {
      if !$0 {
        model.errorMessage = nil
      }
    })
  }

}

private struct ReportScheduleRow: View {
  let schedule: ReportSchedule

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(schedule.input.name)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(schedule.pausedReason == nil ? Color.secondary : Color.orange)
    }
  }

  private var subtitle: String {
    if let reason = schedule.pausedReason {
      return "Paused · \(reason.replacingOccurrences(of: "_", with: " "))"
    }
    let frequency = schedule.input.recurrence.frequency.rawValue.capitalized
    let nextRun = schedule.nextRunAt ?? "pending"
    return "\(frequency) · Next \(nextRun)"
  }
}

private struct ReportTemplateBuilderSheet: View {
  @Environment(\.dismiss) private var dismiss
  let model: AdvancedReportingViewModel
  @State private var name = "Portfolio review"
  @State private var theme = ReportTheme.norviqLight
  @State private var selectedPortfolioIds = Set<String>()
  @State private var selectedKinds: Set<ReportBlockKind> = [.cover, .keyMetrics, .holdings, .allocation, .performance]

  var body: some View {
    NavigationStack {
      Form {
        Section("Presentation") {
          TextField("Template name", text: $name)
          Picker("Theme", selection: $theme) {
            ForEach(ReportTheme.allCases, id: \.self) { Text(themeName($0)).tag($0) }
          }
        }
        Section("Portfolios") {
          ForEach(model.portfolios) { portfolio in
            Toggle(portfolio.name, isOn: selectionBinding(portfolio.id))
          }
        }
        Section("Sections") {
          ForEach(ReportBlockKind.allCases.filter { $0 != .pageBreak && $0 != .customText }, id: \.self) { kind in
            Toggle(kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, isOn: kindBinding(kind))
          }
        }
      }
      .navigationTitle("Report template")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              let created = await model.createTemplate(
                name: name,
                theme: theme,
                portfolioIds: Array(selectedPortfolioIds),
                blockKinds: ReportBlockKind.allCases.filter(selectedKinds.contains)
              )
              if created {
                dismiss()
              }
            }
          }
          .disabled(name.isEmpty || selectedPortfolioIds.isEmpty || selectedKinds.isEmpty || model.isSaving)
        }
      }
    }
  }

  private func selectionBinding(_ id: String) -> Binding<Bool> {
    Binding(
      get: { selectedPortfolioIds.contains(id) },
      set: {
        if $0 {
          selectedPortfolioIds.insert(id)
        } else {
          selectedPortfolioIds.remove(id)
        }
      }
    )
  }

  private func kindBinding(_ kind: ReportBlockKind) -> Binding<Bool> {
    Binding(
      get: { selectedKinds.contains(kind) },
      set: {
        if $0 {
          selectedKinds.insert(kind)
        } else {
          selectedKinds.remove(kind)
        }
      }
    )
  }

  private func themeName(_ theme: ReportTheme) -> String {
    switch theme {
    case .norviqLight: "Norviq Light"
    case .midnight: "Midnight"
    case .advisor: "Advisor"
    }
  }
}

private struct ReportScheduleSheet: View {
  @Environment(\.dismiss) private var dismiss
  let template: ReportTemplate
  let model: AdvancedReportingViewModel
  @State private var frequency = ReportRecurrenceFrequency.monthly

  var body: some View {
    NavigationStack {
      Form {
        LabeledContent("Template", value: template.input.name)
        Picker("Frequency", selection: $frequency) {
          ForEach(ReportRecurrenceFrequency.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        Text(
          "Delivery uses your current time zone at 08:00. The owner is the default recipient; verified shared members can be added from the web builder."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }
      .navigationTitle("Schedule delivery")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Schedule") {
            Task {
              if await model.createSchedule(template: template, frequency: frequency) {
                dismiss()
              }
            }
          }.disabled(model.isSaving)
        }
      }
    }
  }
}
