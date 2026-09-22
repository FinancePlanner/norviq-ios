import Observation
import StockPlanShared
import SwiftUI

/// Card shown under the assistant line that announced a memo.
struct PositionMemoCardView: View {
    let card: PositionMemoCard
    let isSaving: Bool
    let onToggleBookmark: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Position memo · \(card.symbol)", systemImage: "doc.text.magnifyingglass")
                .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            Text(card.title).font(.subheadline.weight(.semibold))
            Text(card.verdict).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                NavigationLink(value: PositionMemoRoute(id: card.id)) { Text("Open") }
                    .buttonStyle(.borderedProminent)
                Button(action: onToggleBookmark) {
                    Label(card.bookmarked ? "Saved" : "Save", systemImage: card.bookmarked ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)
                if isSaving { ProgressView().controlSize(.small) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal, 16)
    }
}

struct PositionMemoRoute: Hashable {
    let id: String
}

struct SavedPositionMemosRoute: Hashable {}

@Observable @MainActor
final class PositionMemoReaderModel {
    private(set) var memo: PositionMemoDetail?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var isDeleted = false

    let id: String
    private let service: any PersistentAssistantServicing

    init(id: String, service: any PersistentAssistantServicing) {
        self.id = id
        self.service = service
    }

    func load() async {
        guard memo == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do { memo = try await service.memo(id: id) }
        catch { errorMessage = message(error, fallback: "This memo could not be opened.") }
    }

    func toggleBookmark() async -> Bool? {
        guard let memo, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            let card = try await service.bookmarkMemo(id: memo.id, bookmarked: !memo.bookmarked)
            self.memo = PositionMemoDetail(
                id: memo.id, askedSymbol: memo.askedSymbol, primarySymbol: memo.primarySymbol,
                title: memo.title, mark: memo.mark, sections: memo.sections, verdict: memo.verdict,
                sources: memo.sources, footer: memo.footer, bookmarked: card.bookmarked, createdAt: memo.createdAt
            )
            return card.bookmarked
        } catch {
            errorMessage = message(error, fallback: "The memo could not be saved.")
            return nil
        }
    }

    func delete() async -> Bool {
        do {
            try await service.deleteMemo(id: id)
            isDeleted = true
            return true
        } catch {
            errorMessage = message(error, fallback: "The memo could not be deleted.")
            return false
        }
    }

    func clearError() { errorMessage = nil }

    private func message(_ error: Error, fallback: String) -> String {
        let value = (error as? LocalizedError)?.errorDescription ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
    }
}

/// The memo itself. Figures in the mark block come from the server, never
/// from the writer's prose.
struct PositionMemoReaderView: View {
    @State private var model: PositionMemoReaderModel
    @State private var confirmsDelete = false
    @Environment(\.dismiss) private var dismiss
    private let onChange: (String, Bool?) -> Void

    /// `onChange` receives the new bookmark flag, or nil when the memo was deleted.
    init(id: String, service: any PersistentAssistantServicing, onChange: @escaping (String, Bool?) -> Void = { _, _ in }) {
        _model = State(initialValue: PositionMemoReaderModel(id: id, service: service))
        self.onChange = onChange
    }

    var body: some View {
        Group {
            if let memo = model.memo {
                content(memo)
            } else if model.isLoading || model.errorMessage == nil {
                ProgressView("Opening memo…")
            } else {
                ContentUnavailableView("Memo unavailable", systemImage: "doc.questionmark", description: Text(model.errorMessage ?? ""))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .vigilScreenBackground()
        .navigationTitle(model.memo?.primarySymbol ?? "Memo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let memo = model.memo {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { if let saved = await model.toggleBookmark() { onChange(memo.id, saved) } }
                    } label: {
                        Image(systemName: memo.bookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(memo.bookmarked ? "Remove from saved memos" : "Save memo")
                    .disabled(model.isSaving)
                    Button(role: .destructive) { confirmsDelete = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete memo")
                }
            }
        }
        .confirmationDialog("Delete this memo?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if await model.delete() {
                        onChange(model.id, nil)
                        dismiss()
                    }
                }
            }
        }
        .task { await model.load() }
    }

    private func content(_ memo: PositionMemoDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(memo.title).font(.title2.weight(.semibold))
                PositionMemoMarkView(mark: memo.mark)
                ForEach(Array(memo.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading.uppercased())
                            .font(.caption2.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph).font(.body)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("VERDICT").font(.caption2.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
                    Text(memo.verdict).font(.body.weight(.semibold))
                }
                Text(memo.footer).font(.footnote).foregroundStyle(.secondary)
                if !memo.sources.isEmpty { sources(memo.sources) }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alert("Memo", isPresented: Binding(
            get: { model.errorMessage != nil && model.memo != nil },
            set: { if !$0 { model.clearError() } }
        )) { Button("OK", role: .cancel) { model.clearError() } } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func sources(_ sources: [PositionMemoSource]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SOURCES").font(.caption2.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                let detail = [source.symbol, source.asOf].compactMap { $0 }.joined(separator: " · ")
                VStack(alignment: .leading, spacing: 2) {
                    if let raw = source.url, let url = URL(string: raw), url.scheme == "https" || url.scheme == "http" {
                        Link(source.label, destination: url).font(.footnote)
                    } else {
                        Text(source.label).font(.footnote)
                    }
                    if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }
}

/// Server-computed numbers: cost, live price, conversion, drawdown, breakeven.
struct PositionMemoMarkView: View {
    let mark: PositionMemoMark

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR MARK").font(.caption2.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
            if let cost = mark.cost {
                row("Cost", "\(PositionMemoFormat.price(cost, mark.costCurrency)) · \(costSourceLabel)")
            } else {
                row("Cost", "Not known")
            }
            if let price = mark.livePrice {
                row("Live \(mark.liveSymbol ?? "")", PositionMemoFormat.price(price, mark.liveCurrency))
            }
            if let price = mark.primaryPrice, mark.primarySymbol != mark.liveSymbol {
                row("Primary \(mark.primarySymbol ?? "")", PositionMemoFormat.price(price, mark.primaryCurrency))
            }
            if let rate = mark.fxRate {
                row("FX \(mark.fxPair ?? "")", [String(format: "%.4f", rate), mark.fxDate].compactMap { $0 }.joined(separator: " · "))
            }
            if let converted = mark.priceInCostCurrency, mark.fxRate != nil {
                row("Live in \(mark.costCurrency ?? "cost currency")", PositionMemoFormat.price(converted, mark.costCurrency))
            }
            if let drawdown = mark.drawdownPercent { row("Versus cost", PositionMemoFormat.percent(drawdown)) }
            if let stated = mark.statedPercent {
                let implied = mark.priceImpliedByStatedPercent.map { " → \(PositionMemoFormat.price($0, mark.costCurrency))" } ?? ""
                row("You said", PositionMemoFormat.percent(stated) + implied)
            }
            if let breakeven = mark.breakevenPercent { row("Needed to break even", PositionMemoFormat.percent(breakeven)) }
            if let shares = mark.shares { row("Shares", shares.formatted()) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var costSourceLabel: String {
        switch mark.costSource {
        case "stated": "from your message"
        case "lots": "from your holdings"
        default: "unknown source"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit())
        }
    }
}

nonisolated enum PositionMemoFormat {
    static func price(_ value: Double, _ currency: String?) -> String {
        let number = String(format: "%.2f", value)
        guard let currency, !currency.isEmpty else { return number }
        return "\(number) \(currency)"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%+.1f%%", value)
    }
}

/// Bookmarked memos, one level off the assistant.
struct SavedPositionMemosView: View {
    let service: any PersistentAssistantServicing
    let onChange: (String, Bool?) -> Void

    @State private var memos: [PositionMemoListItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if memos.isEmpty, !isLoading {
                ContentUnavailableView(
                    "No saved memos",
                    systemImage: "bookmark",
                    description: Text(errorMessage ?? "Ask Q for due diligence, for example “/dd GRAB”, then save the memo.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(memos, id: \.id) { memo in
                NavigationLink(value: PositionMemoRoute(id: memo.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(memo.primarySymbol) · \(memo.title)").font(.subheadline.weight(.semibold))
                        Text(memo.verdict).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }
        .overlay { if isLoading && memos.isEmpty { ProgressView() } }
        .navigationTitle("Saved memos")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            memos = try await service.memos(bookmarked: true, conversationID: nil)
            errorMessage = nil
        } catch {
            errorMessage = "Saved memos could not be loaded."
        }
    }
}
