import StockPlanShared
import SwiftUI

struct TaxReportsSheet: View {
  @Environment(\.dismiss) private var dismiss
  let service: TaxServiceProtocol
  @State private var reports = [TaxReportResponse]()
  @State private var isLoading = true
  @State private var isCreating = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button { Task { await createReport() } } label: {
            Label("Generate transaction workpaper", systemImage: "doc.badge.plus")
          }
          .disabled(isCreating)
        } footer: {
          Text("Workpapers support professional review and are not filing-ready tax returns.")
        }
        Section("Recent reports") {
          if reports.isEmpty && !isLoading { Text("No reports generated yet.").foregroundStyle(.secondary) }
          ForEach(reports) { report in
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(report.kind == .transactionWorkpaper ? "Transaction workpaper" : report.kind.rawValue)
                Text(String(report.taxYear)).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Text(report.status.capitalized).font(.caption).foregroundStyle(report.status == "ready" ? .green : .secondary)
            }
          }
        }
        if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
      }
      .navigationTitle("Tax reports")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .overlay { if isLoading { ProgressView() } }
      .task { await load() }
      .refreshable { await load() }
    }
  }

  private func load() async {
    isLoading = true
    defer { isLoading = false }
    do { reports = try await service.reports() } catch { errorMessage = "Reports could not be loaded." }
  }

  private func createReport() async {
    isCreating = true
    defer { isCreating = false }
    do {
      let report = try await service.createReport(.init(
        taxYear: Calendar.current.component(.year, from: Date()),
        kind: .transactionWorkpaper,
        format: .pdf
      ))
      reports.insert(report, at: 0)
    } catch { errorMessage = "The report could not be generated." }
  }
}
