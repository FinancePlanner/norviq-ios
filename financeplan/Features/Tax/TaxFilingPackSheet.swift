import Factory
import RevenueCat
import StockPlanShared
import SwiftUI

/// The annual filing pack: pick a year, see the exact numbers the national
/// form will carry, then generate the PDF or CSV through the report queue.
/// Numbers come from `GET /v1/tax/filing/preview`; generation reuses the
/// existing reports flow with `kind: .annualFilingPack`.
struct TaxFilingPackSheet: View {
  @Environment(\.dismiss) private var dismiss
  @InjectedObservable(\Container.billingManager) private var billingManager

  let service: TaxServiceProtocol
  @State private var model: TaxFilingPackViewModel
  @State private var isPaywallPresented = false
  @State private var taxPackPackage: Package?
  @State private var isBuyingPack = false

  init(service: TaxServiceProtocol, taxYear: Int = TaxFilingPackViewModel.defaultTaxYear()) {
    self.service = service
    _model = State(initialValue: TaxFilingPackViewModel(service: service, taxYear: taxYear))
  }

  private var years: [Int] {
    let current = Calendar.current.component(.year, from: Date())
    return Array((current - 3)...current).reversed()
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker("Tax year", selection: $model.taxYear) {
            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
          }
          .onChange(of: model.taxYear) { _, year in
            Task {
              await model.load()
              taxPackPackage = await billingManager.taxPackPackage(taxYear: year)
            }
          }
        }

        switch model.state {
        case .idle, .loading:
          Section { ProgressView("Building your pack…") }
        case .paywalled:
          Section {
            VStack(alignment: .leading, spacing: 10) {
              Label("Annual filing pack", systemImage: "lock.doc")
                .font(.headline)
              Text("Pro turns your imported trades and dividends into the numbers your tax return asks for.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Button("Unlock with Pro") { isPaywallPresented = true }
                .buttonStyle(.borderedProminent)
              if let taxPackPackage {
                Button {
                  Task { await buyPack(taxPackPackage) }
                } label: {
                  if isBuyingPack {
                    ProgressView()
                  } else {
                    Text("Buy the \(String(model.taxYear)) pack · \(taxPackPackage.storeProduct.localizedPriceString)")
                  }
                }
                .buttonStyle(.bordered)
                .disabled(isBuyingPack)
                Text("One tax year, no subscription. Unlocks this preview and the PDF/CSV for \(String(model.taxYear)).")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
              if let message = billingManager.errorMessage, !message.isEmpty {
                Text(message).font(.footnote).foregroundStyle(.red)
              }
            }
            .padding(.vertical, 6)
          }
        case .profileIncomplete:
          Section {
            Label("Complete your tax profile for \(String(model.taxYear)) first.", systemImage: "person.text.rectangle")
            Text("The pack needs your jurisdiction and reporting currency.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        case .unsupported(let message), .failed(let message):
          Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
        case .loaded(let preview):
          summarySection(preview)
          ForEach(preview.sections, id: \.id) { section in
            sectionView(section)
          }
          Section {
            Button {
              Task { await model.generate(format: .pdf) }
            } label: {
              Label("Generate PDF", systemImage: "doc.richtext")
            }
            Button {
              Task { await model.generate(format: .csv) }
            } label: {
              Label("Generate CSV", systemImage: "tablecells")
            }
            if let queued = model.queuedReport {
              Text("Queued \(queued.format.rawValue.uppercased()) for \(String(queued.taxYear)). It appears under Reports when ready.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          } footer: {
            Text(preview.disclaimer)
          }
          .disabled(model.isGenerating)
        }
      }
      .navigationTitle("Filing pack")
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
      .task {
        await model.load()
        taxPackPackage = await billingManager.taxPackPackage(taxYear: model.taxYear)
      }
      .sheet(isPresented: $isPaywallPresented) { PaywallView(billingManager: billingManager) }
      .alert("Could not generate", isPresented: Binding(get: { model.generateError != nil }, set: { if !$0 { model.generateError = nil } })) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(model.generateError ?? "")
      }
    }
  }

  /// The webhook that grants the pack lands a moment after the store confirms
  /// the charge, so keep asking the backend until the preview opens.
  private func buyPack(_ package: Package) async {
    isBuyingPack = true
    defer { isBuyingPack = false }
    guard await billingManager.purchaseTaxPack(package) else { return }
    await model.reloadAfterPurchase()
  }

  @ViewBuilder
  private func summarySection(_ preview: FilingPackPreviewResponse) -> some View {
    Section {
      LabeledContent("Form", value: preview.formName)
      LabeledContent("Rule pack", value: preview.rulePackVersion)
      metricRow("Realised gain", preview.summary["totalGain"], currency: preview.reportingCurrency)
      metricRow("Dividends (gross)", preview.summary["totalDividendsGross"], currency: preview.reportingCurrency)
      metricRow("Tax withheld abroad", preview.summary["totalWithholding"], currency: preview.reportingCurrency)
      if preview.unsupportedCount > 0 {
        Label("\(preview.unsupportedCount) row(s) need a manual check", systemImage: "exclamationmark.triangle")
          .foregroundStyle(.orange)
      }
    } header: {
      Text("\(String(preview.taxYear)) · \(preview.jurisdiction.rawValue)")
    } footer: {
      if TaxFilingPackViewModel.isYearOpen(preview.taxYear) {
        Text("Provisional: \(String(preview.taxYear)) is not closed yet. The numbers grow as you import trades and dividends; file from the final pack next spring.")
      }
    }
  }

  @ViewBuilder
  private func sectionView(_ section: FilingPackSectionDTO) -> some View {
    Section {
      if section.rows.isEmpty {
        Text("No rows").foregroundStyle(.secondary)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            GridRow {
              ForEach(section.columns, id: \.self) { column in
                Text(column).font(.caption).foregroundStyle(.secondary)
              }
            }
            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
              GridRow {
                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                  Text(cell).font(.callout.monospacedDigit())
                }
              }
            }
          }
        }
      }
      ForEach(section.notes, id: \.self) { note in
        Text(note).font(.footnote).foregroundStyle(.secondary)
      }
    } header: {
      Text(section.title)
    }
  }

  private func metricRow(_ title: String, _ value: Decimal?, currency: String) -> some View {
    LabeledContent(title) {
      Text((value ?? 0).formatted(.currency(code: currency)))
        .monospacedDigit()
    }
  }
}

@Observable
@MainActor
final class TaxFilingPackViewModel {
  enum State: Equatable {
    case idle
    case loading
    case loaded(FilingPackPreviewResponse)
    case paywalled
    case profileIncomplete
    case unsupported(String)
    case failed(String)
  }

  var taxYear: Int
  var state: State = .idle
  var isGenerating = false
  var queuedReport: TaxReportResponse?
  var generateError: String?

  private let service: TaxServiceProtocol

  /// The year people are dealing with right now: during the filing window
  /// (January–June) that is last year's return; from July the year in
  /// progress, which the preview can already show and the pack can be bought for.
  static func defaultTaxYear(on date: Date = Date(), calendar: Calendar = .current) -> Int {
    let year = calendar.component(.year, from: date)
    return calendar.component(.month, from: date) <= 6 ? year - 1 : year
  }

  /// True while the tax year has not ended, so its numbers are still moving.
  static func isYearOpen(_ taxYear: Int, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
    taxYear >= calendar.component(.year, from: date)
  }

  init(service: TaxServiceProtocol, taxYear: Int) {
    self.service = service
    self.taxYear = taxYear
  }

  func load() async {
    state = .loading
    queuedReport = nil
    do {
      state = .loaded(try await service.filingPreview(taxYear: taxYear))
    } catch let TaxServiceError.http(statusCode, _) {
      switch statusCode {
      case 402, 403: state = .paywalled
      case 409: state = .profileIncomplete
      case 422: state = .unsupported("The filing pack is not available for your jurisdiction yet.")
      default: state = .failed("The server returned \(statusCode).")
      }
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  /// After a per-year purchase: the entitlement arrives through RevenueCat's
  /// webhook, so poll the preview until it stops being paywalled.
  func reloadAfterPurchase(attempts: Int = 6, delay: Duration = .seconds(2)) async {
    for attempt in 1 ... max(1, attempts) {
      await load()
      if state != .paywalled { return }
      if attempt < attempts {
        try? await Task.sleep(for: delay)
      }
    }
  }

  func generate(format: TaxReportFormat) async {
    isGenerating = true
    defer { isGenerating = false }
    do {
      queuedReport = try await service.createReport(.init(taxYear: taxYear, kind: .annualFilingPack, format: format))
    } catch {
      generateError = error.localizedDescription
    }
  }
}
