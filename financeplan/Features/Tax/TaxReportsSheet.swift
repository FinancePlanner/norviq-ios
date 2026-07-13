import Factory
import StockPlanShared
import SwiftUI

struct TaxReportsSheet: View {
  private struct ReportShareItem: Identifiable {
    let id = UUID()
    let url: URL
  }

  @Environment(\.dismiss) private var dismiss
  @InjectedObservable(\Container.billingManager) private var billingManager
  let service: TaxServiceProtocol
  @State private var reports = [TaxReportResponse]()
  @State private var reportTaxYear = Calendar.current.component(.year, from: Date())
  @State private var reportFormat: TaxReportFormat = .pdf
  @State private var isLoading = true
  @State private var isCreating = false
  @State private var downloadingReportID: String?
  @State private var shareItem: ReportShareItem?
  @State private var isPaywallPresented = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      List {
        if !billingManager.isPro {
          Section {
            VStack(alignment: .leading, spacing: 10) {
              Label("Advisor-ready tax reports", systemImage: "lock.doc")
                .font(.headline)
              Text("Preview your report history for free. Pro unlocks generation and PDF or CSV downloads.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Button("Unlock with Pro") { isPaywallPresented = true }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 6)
          }
        }
        Section {
          Picker("Tax year", selection: $reportTaxYear) {
            ForEach(reportYears, id: \.self) { year in
              Text(String(year)).tag(year)
            }
          }
          Picker("Format", selection: $reportFormat) {
            Text("PDF").tag(TaxReportFormat.pdf)
            Text("CSV").tag(TaxReportFormat.csv)
          }
          .pickerStyle(.segmented)

          Button {
            if billingManager.isPro { Task { await createReport() } }
            else { isPaywallPresented = true }
          } label: {
            Label(
              "Generate \(reportFormat.rawValue.uppercased()) workpaper",
              systemImage: "doc.badge.plus"
            )
          }
          .disabled(isCreating)
        } footer: {
          Text("Workpapers support professional review and are not filing-ready tax returns.")
        }
        Section("Recent reports") {
          if reports.isEmpty && !isLoading { Text("No reports generated yet.").foregroundStyle(.secondary) }
          ForEach(reports) { report in
            Button {
              if billingManager.isPro { Task { await download(report) } }
              else { isPaywallPresented = true }
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(report.kind == .transactionWorkpaper ? "Transaction workpaper" : report.kind.rawValue)
                    .foregroundStyle(.primary)
                  Text("\(report.taxYear) · \(report.format.rawValue.uppercased())")
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if downloadingReportID == report.id {
                  ProgressView()
                } else if !billingManager.isPro {
                  Image(systemName: "lock.fill").foregroundStyle(.secondary)
                } else if report.status == "ready" {
                  Image(systemName: "arrow.down.doc").foregroundStyle(.tint)
                } else {
                  Text(report.status.capitalized).font(.caption).foregroundStyle(.secondary)
                }
              }
            }
            .buttonStyle(.plain)
            .disabled(downloadingReportID != nil || (billingManager.isPro && report.status != "ready"))
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
      .sheet(isPresented: $isPaywallPresented) { PaywallView(billingManager: billingManager) }
      .sheet(item: $shareItem) { item in
        NavigationStack {
          VStack(spacing: 20) {
            Image(systemName: "doc.badge.checkmark").font(.system(size: 48)).foregroundStyle(.green)
            Text("Report ready").font(.title2.bold())
            Text("Save it to Files, send it to your advisor, or open it in another app.")
              .multilineTextAlignment(.center).foregroundStyle(.secondary)
            ShareLink(item: item.url) {
              Label("Share or save report", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
          }
          .padding(24)
          .navigationTitle("Tax report")
          .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
      }
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
        taxYear: reportTaxYear,
        kind: .transactionWorkpaper,
        format: reportFormat
      ))
      reports.insert(report, at: 0)
      if report.status != "ready" {
        Task { await pollReport(id: report.id) }
      }
    } catch { errorMessage = "The report could not be generated." }
  }

  private func pollReport(id: String) async {
    for attempt in 0 ..< 8 {
      if attempt > 0 {
        let delaySeconds = min(8, 1 << min(attempt - 1, 3))
        do {
          try await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
        } catch {
          return
        }
      }

      guard let refreshed = try? await service.reports(),
            let report = refreshed.first(where: { $0.id == id })
      else { continue }
      if let index = reports.firstIndex(where: { $0.id == id }) {
        reports[index] = report
      } else {
        reports.insert(report, at: 0)
      }
      if ["ready", "failed", "expired"].contains(report.status) { return }
    }
  }

  private var reportYears: [Int] {
    let currentYear = Calendar.current.component(.year, from: Date())
    return Array((currentYear - 6 ... currentYear).reversed())
  }

  private func download(_ report: TaxReportResponse) async {
    downloadingReportID = report.id
    defer { downloadingReportID = nil }
    do {
      shareItem = ReportShareItem(url: try await service.downloadReport(report))
    } catch {
      errorMessage = "The report could not be downloaded. Refresh to check whether it is ready."
    }
  }
}
