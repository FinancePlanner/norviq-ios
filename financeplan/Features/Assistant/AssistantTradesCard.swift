import Foundation
import StockPlanShared
import SwiftUI

// The review card for a `record_trades` action: trades Q read from a
// screenshot. Its rules and English copy are the web card's
// (`norviq-web-v2` `features/dashboard/assistant/trades.ts` and
// `TradesCard.svelte`). Every value is editable and only ticked rows are
// saved: the confirm body is built from the rows as they stand, never from the
// stored proposal. All text from the model renders verbatim.

// MARK: - Numbers

/// Reads typed numbers strictly, so a cell never saves a number the user did
/// not mean. It accepts a short list of shapes and nothing else: "1,5" and
/// "1.5" are 1.5, "1 234" and "1,234,567" are grouped, and "1,234" is refused
/// because it is 1.234 in one country and 1234 in another (R16). A single dot
/// group ("1.000") stays a decimal, because stored values use dots (R21). Only
/// the ends are trimmed, so "100 150.25" pasted from two cells is refused (R20).
///
/// Main-actor bound, like every caller: `Regex` is not `Sendable`, so the
/// compiled patterns can only be shared statics under one isolation.
enum TradeNumber {
    struct Hint: Equatable {
        let text: String
        /// The dot-thousands warning rather than the plain "Saves as".
        let warns: Bool
    }

    // Compiled once, and checked when the app is built. `[0-9]`, not `\d`,
    // which in Swift also matches other scripts' digits.

    /// One comma and exactly three digits after a non-zero integer part.
    private static let ambiguousComma = /^[+-]?0*[1-9][0-9]*,[0-9]{3}$/
    private static let plain = /^(?:[0-9]+|[0-9]*[.,][0-9]+|[0-9]+\.)$/
    /// Groups of three after 1-3 digits, one kind of separator throughout, and
    /// a decimal part that uses the other mark.
    private static let grouped: [Regex<(Substring, Substring, Substring?)>] = [
        /^([1-9][0-9]{0,2}(?:,[0-9]{3})+)(?:\.([0-9]+))?$/,
        /^([1-9][0-9]{0,2}(?:\.[0-9]{3})+)(?:,([0-9]+))?$/,
        /^([1-9][0-9]{0,2}(?: [0-9]{3})+)(?:,([0-9]+))?$/,
        /^([1-9][0-9]{0,2}(?:\u{00A0}[0-9]{3})+)(?:,([0-9]+))?$/,
        /^([1-9][0-9]{0,2}(?:'[0-9]{3})+)(?:[.,]([0-9]+))?$/,
    ]
    private static let spaceGroupDot = /^[+-]?[1-9][0-9]{0,2}(?:[ \u{00A0}][0-9]{3})+\.[0-9]+$/
    private static let thousandsLookalike = /^[1-9][0-9]{0,2}\.[0-9]{3}$/

    private static func trimmed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The number a cell holds, or nil when it is blank or not clearly one number.
    static func parse(_ raw: String) -> Double? {
        let text = trimmed(raw)
        let sign = text.first.map { $0 == "+" || $0 == "-" } == true ? String(text.prefix(1)) : ""
        let body = String(text.dropFirst(sign.count))
        if body.isEmpty || body.wholeMatch(of: ambiguousComma) != nil { return nil }
        let digits: String
        if body.wholeMatch(of: plain) != nil {
            digits = body.replacingOccurrences(of: ",", with: ".")
        } else if let found = grouped.lazy.compactMap({ body.wholeMatch(of: $0) }).first {
            let whole = String(found.output.1).filter { $0.isASCII && $0.isNumber }
            let fraction = found.output.2.map { "." + $0 } ?? ""
            digits = whole + fraction
        } else {
            return nil
        }
        guard let value = Double(sign + digits), value.isFinite else { return nil }
        return value
    }

    /// A number as text, without grouping or an exponent: 5e-7 is "0.0000005".
    static func format(_ value: Double) -> String {
        let described = "\(abs(value))"
        let parts = described.split(separator: "e", maxSplits: 1).map(String.init)
        let mantissa = parts[0]
        let exponent = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        var digits = mantissa.replacingOccurrences(of: ".", with: "")
        var point = (mantissa.firstIndex(of: ".").map { mantissa.distance(from: mantissa.startIndex, to: $0) } ?? mantissa.count) + exponent
        if point <= 0 {
            digits = String(repeating: "0", count: 1 - point) + digits
            point = 1
        }
        if point > digits.count {
            digits += String(repeating: "0", count: point - digits.count)
        }
        var whole = String(digits.prefix(point))
        var fraction = String(digits.dropFirst(point))
        while fraction.hasSuffix("0") { fraction.removeLast() }
        while whole.count > 1, whole.hasPrefix("0") { whole.removeFirst() }
        let sign = value.sign == .minus ? "-" : ""
        return sign + whole + (fraction.isEmpty ? "" : "." + fraction)
    }

    /// The cell rewritten as the number that will be sent, when it is one:
    /// "1,5" becomes "1.5". Anything else is left for the row's message.
    static func tidy(_ raw: String) -> String {
        guard !trimmed(raw).isEmpty, let value = parse(raw) else { return raw }
        return format(value)
    }

    /// What a cell will be saved as, when that differs from what was typed.
    /// Empty when the text is blank, unreadable, or already the saved value.
    static func savesAs(_ raw: String) -> String {
        let text = trimmed(raw)
        guard !text.isEmpty, let value = parse(raw) else { return "" }
        let saved = format(value)
        return saved == text ? "" : saved
    }

    /// The line under a numeric cell (R18, R21), or nil. An edited cell that
    /// looks like a dot thousands group ("1.234") warns, because it saves as
    /// 1.234 and a user whose country groups with dots may mean 1234. A stored
    /// value stays quiet. Otherwise it is the plain "Saves as" when that
    /// differs from what was typed.
    static func hint(for raw: String, stored: String?) -> Hint? {
        let typed = trimmed(raw)
        if typed != trimmed(stored ?? ""), typed.wholeMatch(of: thousandsLookalike) != nil, let value = parse(typed) {
            let saved = format(value)
            let grouped = typed.replacingOccurrences(of: ".", with: "")
            return Hint(text: String(localized: "Saves as \(saved), not \(grouped)"), warns: true)
        }
        let saved = savesAs(raw)
        return saved.isEmpty ? nil : Hint(text: String(localized: "Saves as \(saved)"), warns: false)
    }

    /// Why a typed number was refused as unclear, or "" when that is not the reason.
    static func unclearProblem(_ raw: String) -> String {
        let text = trimmed(raw)
        if text.wholeMatch(of: ambiguousComma) != nil {
            let body = text.first.map { $0 == "+" || $0 == "-" } == true ? String(text.dropFirst()) : text
            let halves = body.split(separator: ",", maxSplits: 1).map(String.init)
            var whole = halves[0]
            while whole.count > 1, whole.hasPrefix("0") { whole.removeFirst() }
            let tail = halves.count > 1 ? halves[1] : ""
            return String(localized: "Is that \(whole + tail) or \(whole + "." + tail)? Type it without the comma.")
        }
        if text.wholeMatch(of: spaceGroupDot) != nil {
            return String(localized: "Spaces and a decimal point do not go together here. Type it without the spaces.")
        }
        return ""
    }

    /// True for a `YYYY-MM-DD` that exists on the calendar.
    static func isRealDate(_ raw: String) -> Bool {
        TradeDate.date(from: raw) != nil
    }
}

/// `YYYY-MM-DD` dates, read and written in UTC so no time zone moves a day.
nonisolated enum TradeDate {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static func date(from raw: String) -> Date? {
        let parts = raw.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components
        else { return nil }
        return date
    }

    static func string(from date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The picker shows and picks days in the device's time zone. Noon there
    /// is on the row's day in every zone, so the day survives the round trip.
    static func localNoon(from raw: String, calendar local: Calendar = .current) -> Date? {
        guard let day = date(from: raw) else { return nil }
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = 12
        return local.date(from: parts)
    }

    /// The `YYYY-MM-DD` of a day picked in the device's time zone.
    static func string(fromLocal date: Date, calendar local: Calendar = .current) -> String {
        let parts = local.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

// MARK: - Model

/// One row as it stands on the card.
struct AssistantTradeRow: Equatable, Identifiable {
    static let alreadyRecorded = "already_recorded"
    static let lowConfidence = 0.8

    let id: Int
    var symbol: String
    /// `buy` or `sell`.
    var side: String
    var quantity: String
    var price: String
    var tradeDate: String
    /// Blank when the model read none; the account's currency is then used.
    var currency: String
    /// Blank when the model read none.
    var fees: String
    var keep: Bool
    let confidence: Double?
    let issues: [AITradeIssue]
    /// The numeric cells as they came from the backend. A stored value gets
    /// no dot-thousands warning (R21).
    let storedQuantity: String
    let storedPrice: String
    let storedFees: String

    init(index: Int, trade: AIProposedTrade) {
        id = index
        symbol = trade.symbol
        side = trade.side
        quantity = TradeNumber.format(trade.quantity)
        price = TradeNumber.format(trade.price)
        tradeDate = trade.tradeDate
        currency = trade.currency ?? ""
        fees = trade.fees.map(TradeNumber.format) ?? ""
        confidence = trade.confidence
        issues = trade.issues
        storedQuantity = quantity
        storedPrice = price
        storedFees = fees
        keep = !trade.issues.contains { $0.code == Self.alreadyRecorded && $0.blocking }
    }

    /// Already recorded: it cannot be ticked or edited (decision 11).
    var isLocked: Bool { issues.contains { $0.code == Self.alreadyRecorded && $0.blocking } }

    /// Confidence below 0.8, or none at all, which is never high (R15).
    var isLowConfidence: Bool { confidence.map { $0 < Self.lowConfidence } ?? true }

    /// Kept and allowed to be: what gets sent.
    var isSent: Bool { keep && !isLocked }

    /// Why this row cannot be sent yet, or "" when it can.
    var problem: String {
        if symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Enter a symbol.")
        }
        guard let shares = TradeNumber.parse(quantity), shares > 0 else {
            let unclear = TradeNumber.unclearProblem(quantity)
            return unclear.isEmpty ? String(localized: "Enter the number of shares.") : unclear
        }
        guard let amount = TradeNumber.parse(price), amount > 0 else {
            let unclear = TradeNumber.unclearProblem(price)
            return unclear.isEmpty ? String(localized: "Enter the price.") : unclear
        }
        if !TradeNumber.isRealDate(tradeDate) { return String(localized: "Enter the date.") }
        if !fees.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, (TradeNumber.parse(fees) ?? -1) < 0 {
            let unclear = TradeNumber.unclearProblem(fees)
            return unclear.isEmpty ? String(localized: "Fees must be a number, or blank.") : unclear
        }
        return ""
    }

    /// The confirm row: numbers parsed, a blank currency or fees left out.
    var reviewed: AIReviewedTrade {
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let fee = fees.trimmingCharacters(in: .whitespacesAndNewlines)
        return AIReviewedTrade(
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines),
            side: side,
            quantity: TradeNumber.parse(quantity) ?? 0,
            price: TradeNumber.parse(price) ?? 0,
            tradeDate: tradeDate,
            currency: code.isEmpty ? nil : code,
            fees: fee.isEmpty ? nil : TradeNumber.parse(fee)
        )
    }
}

/// A trades card's state: the rows as edited, the chosen portfolio, and the
/// last refusal. Kept by the view model, keyed by action, so edits outlive
/// scrolling and reloads.
struct AssistantTradesReview: Equatable {
    static let toolName = "record_trades"
    /// The backend's `stocks.IBKRSyncedRefusal`, same copy.
    static let syncedCopy = String(localized: "This portfolio syncs from IBKR, so saved trades would be overwritten. Pick another portfolio.")
    /// Shown while a kept row is a sell (R24): ledger sells do not reach annual tax totals.
    static let sellTaxNote = String(localized: "Sells update realized P&L, not yet your annual tax figures.")
    static let expiredCopy = String(localized: "This review expired. Send the screenshot again.")
    static let closedCopy = String(localized: "Those trades were not saved and this review is closed. Send the screenshot again.")
    static let retryCopy = String(localized: "That did not go through. Try again.")
    static let upgradeCopy = String(localized: "Saving trades from a screenshot is part of Pro.")
    /// The answer to a save was lost, and the action is gone (R30).
    static let maybeSavedCopy = String(localized: "This may have been saved. Check your portfolio before sending the screenshot again.")
    /// The answer to a save was lost and the action still waits: the save may
    /// yet finish, so this does not say it failed. A retry that finds it done
    /// gets a 409 and says so.
    static let unconfirmedCopy = String(localized: "We couldn't confirm this save. Try again; if it went through, this card will say so.")

    private static let summaryPattern = /Record .+? in (.+)\./
    private static let fractionalISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plainISO = ISO8601DateFormatter()

    /// The backend's ISO 8601 expiry, with or without fractional seconds.
    static func expiryDate(_ raw: String) -> Date? {
        fractionalISO.date(from: raw) ?? plainISO.date(from: raw)
    }

    struct ListOption: Equatable, Identifiable, Hashable {
        let id: String
        let name: String
    }

    /// A confirm the backend refused, placed on the rows that were sent.
    struct Refusal: Equatable {
        var message: String
        /// Messages by position in `rows`.
        var byRow: [Int: [String]]
        /// Errors that name no row that was sent.
        var unplaced: [String]
    }

    let actionID: String
    let summary: String
    let expiresAt: String
    let proposal: TradesProposalDTO
    var rows: [AssistantTradeRow]
    var portfolioListID: String
    var refusal: Refusal?
    /// A save was sent from this card, whatever came back. A later 409 then
    /// may mean that save went through.
    var hasAttemptedSave = false
    /// Set once the card can no longer be saved: it expired, was answered, or
    /// failed after the save began.
    var closedMessage: String?

    /// Nil unless the action is `record_trades` and its arguments decode; the
    /// plain card is shown then.
    init?(action: AIPendingActionResponse) {
        guard action.toolName == Self.toolName,
              let proposal = TradesProposalDTO.decode(arguments: action.arguments)
        else { return nil }
        actionID = action.id
        summary = action.summary
        expiresAt = action.expiresAt
        self.proposal = proposal
        rows = proposal.trades.enumerated().map { AssistantTradeRow(index: $0.offset, trade: $0.element) }
        portfolioListID = proposal.portfolioListId
    }

    private static func same(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    /// Only the list the stored preview found synced blocks saving. The client
    /// cannot tell whether another list is synced; the backend refuses that on save.
    var blockedBySync: Bool { proposal.synced && Self.same(portfolioListID, proposal.portfolioListId) }

    /// Positions in `rows` of the rows that would be sent, in order: submitted
    /// index i is row `keptIndexes[i]`.
    var keptIndexes: [Int] { rows.indices.filter { rows[$0].isSent } }

    /// Why a kept row cannot be sent, or "" (also for rows that are not sent).
    func problem(at index: Int) -> String {
        rows[index].isSent ? rows[index].problem : ""
    }

    /// Ignoring a save in flight, which the view adds.
    var canSave: Bool {
        closedMessage == nil && !blockedBySync && !keptIndexes.isEmpty && keptIndexes.allSatisfy { rows[$0].problem.isEmpty }
    }

    var confirmTrades: [AIReviewedTrade] { keptIndexes.map { rows[$0].reviewed } }

    var confirmBody: AITradesConfirmRequest {
        AITradesConfirmRequest(portfolioListId: portfolioListID, trades: confirmTrades)
    }

    var showsSellTaxNote: Bool { keptIndexes.contains { rows[$0].side == "sell" } }

    var skippedRowsText: String {
        let count = proposal.skippedRows
        if count <= 0 { return "" }
        if count == 1 { return String(localized: "1 row left out (options, shorts, dividends or fees).") }
        return String(localized: "\(count) rows left out (options, shorts, dividends or fees).")
    }

    var saveTitle: String {
        let count = keptIndexes.count
        return count == 1 ? String(localized: "Save 1 trade") : String(localized: "Save \(count) trades")
    }

    /// The portfolio name in a summary like "Record 2 buys and 1 sell in Growth.".
    /// Empty when it does not fit.
    static func listName(fromSummary summary: String) -> String {
        let text = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = text.wholeMatch(of: summaryPattern) else { return "" }
        return String(match.output.1)
    }

    private var storedName: String {
        let name = Self.listName(fromSummary: summary)
        return name.isEmpty ? String(localized: "the proposed portfolio") : name
    }

    /// The picker's choices. The destination must always be visible, so when
    /// the lists did not load, or the stored list is not among them, the
    /// stored list comes first, named from the summary. The stored list keeps
    /// the stored id, whatever case the lists spell it in.
    func options(lists: [PortfolioListDTOResponse]?) -> [ListOption] {
        let loaded = (lists ?? []).map { list in
            ListOption(id: Self.same(list.id, proposal.portfolioListId) ? proposal.portfolioListId : list.id, name: list.name)
        }
        if loaded.contains(where: { $0.id == proposal.portfolioListId }) { return loaded }
        return [ListOption(id: proposal.portfolioListId, name: storedName)] + loaded
    }

    func destination(lists: [PortfolioListDTOResponse]?) -> String {
        options(lists: lists).first { Self.same($0.id, portfolioListID) }?.name ?? storedName
    }

    /// Places a 422's row errors, which index the submitted rows, on `rows`.
    mutating func refuse(_ message: String, rowErrors: [AITradeRowError]) {
        let sent = keptIndexes
        var byRow: [Int: [String]] = [:]
        var unplaced: [String] = []
        for error in rowErrors {
            if sent.indices.contains(error.index) {
                byRow[sent[error.index], default: []].append(error.message)
            } else {
                unplaced.append(error.message)
            }
        }
        refusal = Refusal(message: message, byRow: byRow, unplaced: unplaced)
    }
}

// MARK: - View

/// Shown in place of the plain confirmation card for `record_trades`.
struct AssistantTradesCard: View {
    @Binding var review: AssistantTradesReview
    let lists: [PortfolioListDTOResponse]?
    let isBusy: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    /// Tries the portfolio lists again, for a card blocked by sync with none to pick.
    let onReloadLists: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let closed = review.closedMessage {
                // "Not applied" would be false when the save may have gone through.
                if closed != AssistantTradesReview.maybeSavedCopy {
                    Label("Not applied", systemImage: "xmark.circle").font(.subheadline.weight(.semibold))
                }
                Text(verbatim: closed).font(.subheadline)
            } else {
                header
                destination
                if review.blockedBySync {
                    Text(AssistantTradesReview.syncedCopy)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.danger)
                    if review.options(lists: lists).count <= 1 {
                        Button("Load your portfolios", action: onReloadLists)
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                    }
                }
                ForEach($review.rows) { $row in
                    AssistantTradeRowEditor(
                        row: $row,
                        baseCurrency: review.proposal.baseCurrency,
                        problem: review.problem(at: row.id),
                        rowErrors: review.refusal?.byRow[row.id] ?? []
                    )
                }
                .disabled(isBusy)
                footer
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card))
        .padding(.horizontal, 16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Review trades", systemImage: "list.bullet.rectangle").font(.subheadline.weight(.semibold))
            Text("Check each row against your screenshot. Only ticked rows are saved.")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            if let expiry = Self.expiry(review.expiresAt) {
                Text("Expires \(expiry)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder private var destination: some View {
        let options = review.options(lists: lists)
        if options.count > 1 {
            Picker("Portfolio", selection: $review.portfolioListID) {
                ForEach(options) { Text(verbatim: $0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            .disabled(isBusy)
        } else {
            Text("Saving to \(Text(verbatim: review.destination(lists: lists)).bold())").font(.subheadline)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !review.skippedRowsText.isEmpty {
                Text(verbatim: review.skippedRowsText).font(.caption).foregroundStyle(AppTheme.Colors.secondaryText)
            }
            if review.showsSellTaxNote {
                Text(AssistantTradesReview.sellTaxNote).font(.caption).foregroundStyle(AppTheme.Colors.secondaryText)
            }
            if let refusal = review.refusal {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: refusal.message)
                    ForEach(Array(refusal.unplaced.enumerated()), id: \.offset) { Text(verbatim: $0.element) }
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.danger)
            }
            HStack(spacing: 8) {
                Button(review.saveTitle, action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(!review.canSave || isBusy)
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                if isBusy { ProgressView().controlSize(.small) }
            }
        }
    }

    /// For both review cards. `.decimalPad` has no minus sign, and on some
    /// locales no dot, so "1.5" typed from a screenshot could not be entered.
    static let numberKeyboard: UIKeyboardType = .numbersAndPunctuation

    /// The expiry as a local time; the backend sends ISO 8601.
    static func expiry(_ raw: String) -> String? {
        guard let date = AssistantTradesReview.expiryDate(raw) else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// One editable row. A locked (already recorded) row shows its values and cannot change.
private struct AssistantTradeRowEditor: View {
    @Binding var row: AssistantTradeRow
    let baseCurrency: String
    let problem: String
    let rowErrors: [String]

    private enum Field: Hashable { case quantity, price, fees }
    @FocusState private var focus: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    row.keep.toggle()
                } label: {
                    Image(systemName: row.isSent ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(row.isLocked ? AppTheme.Colors.secondaryText : AppTheme.Colors.tint)
                }
                .buttonStyle(.plain)
                .disabled(row.isLocked)
                .accessibilityLabel(Text("Save \(row.symbol)"))
                .accessibilityAddTraits(row.isSent ? .isSelected : [])
                Picker("Side", selection: $row.side) {
                    Text("Buy").tag("buy")
                    Text("Sell").tag("sell")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)
                TextField("Symbol", text: $row.symbol)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.weight(.semibold))
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    numberCell("Shares", text: $row.quantity, stored: row.storedQuantity, field: .quantity)
                    numberCell("Price", text: $row.price, stored: row.storedPrice, field: .price)
                }
                GridRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Date").font(.caption2).foregroundStyle(AppTheme.Colors.secondaryText)
                        DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                            .labelsHidden()
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currency").font(.caption2).foregroundStyle(AppTheme.Colors.secondaryText)
                            TextField(baseCurrency, text: currencyBinding)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                        numberCell("Fees", text: $row.fees, stored: row.storedFees, field: .fees)
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            notes
        }
        .disabled(row.isLocked)
        .padding(10)
        .background(
            (row.isLowConfidence || !rowErrors.isEmpty) ? AppTheme.Colors.warning.opacity(0.08) : Color.clear,
            in: .rect(cornerRadius: 10)
        )
        .onChange(of: focus) { old, _ in
            // Shows the number that will be sent: "1,5" becomes "1.5".
            switch old {
            case .quantity: row.quantity = TradeNumber.tidy(row.quantity)
            case .price: row.price = TradeNumber.tidy(row.price)
            case .fees: row.fees = TradeNumber.tidy(row.fees)
            case nil: break
            }
        }
    }

    private func numberCell(_ label: LocalizedStringKey, text: Binding<String>, stored: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(AppTheme.Colors.secondaryText)
            TextField(label, text: text)
                .keyboardType(AssistantTradesCard.numberKeyboard)
                .focused($focus, equals: field)
            if let hint = TradeNumber.hint(for: text.wrappedValue, stored: stored) {
                Text(verbatim: hint.text)
                    .font(.caption2)
                    .foregroundStyle(hint.warns ? AppTheme.Colors.warning : AppTheme.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder private var notes: some View {
        VStack(alignment: .leading, spacing: 2) {
            if row.isLowConfidence {
                Text("Hard to read — check").foregroundStyle(AppTheme.Colors.warning)
            }
            ForEach(Array(row.issues.enumerated()), id: \.offset) { _, issue in
                Text(verbatim: issue.message)
                    .foregroundStyle(issue.blocking ? AppTheme.Colors.danger : AppTheme.Colors.warning)
            }
            if !problem.isEmpty {
                Text(verbatim: problem).foregroundStyle(AppTheme.Colors.danger)
            }
            ForEach(Array(rowErrors.enumerated()), id: \.offset) { _, message in
                Text(verbatim: message).foregroundStyle(AppTheme.Colors.danger)
            }
        }
        .font(.caption)
    }

    /// A date the model read that is not a real date shows today until changed;
    /// the row says "Enter the date." meanwhile. The picker runs in the device's
    /// time zone, so the day goes through local noon both ways.
    private var dateBinding: Binding<Date> {
        Binding(
            get: { TradeDate.localNoon(from: row.tradeDate) ?? .now },
            set: { row.tradeDate = TradeDate.string(fromLocal: $0) }
        )
    }

    private var currencyBinding: Binding<String> {
        Binding(get: { row.currency }, set: { row.currency = String($0.prefix(3)) })
    }
}
