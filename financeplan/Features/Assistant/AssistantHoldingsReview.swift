import Foundation
import StockPlanShared

// The state behind the holdings-review card (`update_holdings`): holdings Q
// read from an attached file. Modelled on the trades review. Every value is
// editable and only ticked rows are saved: the confirm body is built from the
// rows as they stand, never from the stored card. Numbers are read with the
// trades card's `TradeNumber`, so "1,5" is 1.5 and "1,234" is refused.

/// One row as it stands on the card.
struct AssistantHoldingRow: Equatable, Identifiable {
    let id: Int
    var symbol: String
    var shares: String
    /// The average cost per share. Blank when the file had none.
    var avgPrice: String
    /// `YYYY-MM-DD`, or blank.
    var buyDate: String
    var keep = true
    let existing: String
    let willReplaceImport: Bool
    /// The numeric cells as they came from the backend. A stored value gets
    /// no dot-thousands warning.
    let storedShares: String
    let storedAvgPrice: String

    init(index: Int, holding: AIProposedHolding) {
        id = index
        symbol = holding.symbol
        shares = holding.shares.map(TradeNumber.format) ?? ""
        avgPrice = holding.avgPrice.map(TradeNumber.format) ?? ""
        buyDate = holding.buyDate ?? ""
        existing = holding.existing
        willReplaceImport = holding.willReplaceImport
        storedShares = shares
        storedAvgPrice = avgPrice
    }

    /// What saving this row does to what the portfolio holds already.
    var badge: String {
        if existing == "imported" || willReplaceImport { return String(localized: "Replaces import") }
        if existing == "manual" || existing == "mixed" { return String(localized: "Replaces existing") }
        return String(localized: "holdings.badge.new", defaultValue: "New")
    }

    /// Why this row cannot be sent yet, or "" when it can.
    var problem: String {
        if symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Enter a symbol.")
        }
        guard let count = TradeNumber.parse(shares), count > 0 else {
            let unclear = TradeNumber.unclearProblem(shares)
            return unclear.isEmpty ? String(localized: "Enter the number of shares.") : unclear
        }
        guard let cost = TradeNumber.parse(avgPrice), cost > 0 else {
            let unclear = TradeNumber.unclearProblem(avgPrice)
            return unclear.isEmpty ? String(localized: "Enter the average price.") : unclear
        }
        let date = buyDate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !date.isEmpty, !TradeNumber.isRealDate(date) {
            return String(localized: "Enter the date as YYYY-MM-DD, or leave it blank.")
        }
        return ""
    }

    /// The confirm row: numbers parsed, a blank date left out.
    var reviewed: AIReviewedHolding {
        let date = buyDate.trimmingCharacters(in: .whitespacesAndNewlines)
        return AIReviewedHolding(
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines),
            shares: TradeNumber.parse(shares),
            avgPrice: TradeNumber.parse(avgPrice),
            buyDate: date.isEmpty ? nil : date
        )
    }
}

/// A holdings card's state: the rows as edited, the replace switch, and the
/// last refusal. Kept by the view model, keyed by action, so edits outlive
/// scrolling and reloads.
struct AssistantHoldingsReview: Equatable {
    static let toolName = "update_holdings"
    static let expiredCopy = String(localized: "This card expired. Send the file again.")
    static let retryCopy = String(localized: "That did not go through. Try again.")
    static let upgradeCopy = String(localized: "Importing holdings from a file is part of Pro.")
    /// The answer to a save was lost, and the action is gone.
    static let maybeSavedCopy = String(localized: "This may have been saved. Check your portfolio before sending the file again.")
    static let closedCopy = String(localized: "Those holdings were not saved and this card is closed. Send the file again.")

    /// A confirm the backend refused, placed on the rows that were sent.
    struct Refusal: Equatable {
        var message: String
        /// The refusal is a `holdings_collision`: the "Replace existing" switch applies.
        var isCollision: Bool
        /// Messages by position in `rows`.
        var byRow: [Int: [String]]
        /// Errors that name no row that was sent.
        var unplaced: [String]
    }

    let actionID: String
    let summary: String
    let expiresAt: String
    let proposal: AIProposedHoldings
    var rows: [AssistantHoldingRow]
    let portfolioListID: String
    /// The "Replace existing" switch. Off until a collision asks for it.
    var replaceExisting = false
    var refusal: Refusal?
    /// A save was sent from this card, whatever came back.
    var hasAttemptedSave = false
    /// Set once the card can no longer be saved: it expired or failed after the save began.
    var closedMessage: String?
    /// The backend's answer to a save: "Saved AAPL, MSFT." and, on a partial
    /// save, " Couldn't save XYZ: reason." after it. The card is settled.
    var completedMessage: String?

    /// Nil unless the action is `update_holdings` and its arguments decode;
    /// the plain card is shown then.
    init?(action: AIPendingActionResponse) {
        guard action.toolName == Self.toolName,
              let proposal = AIProposedHoldings.decode(arguments: action.arguments)
        else { return nil }
        actionID = action.id
        summary = action.summary
        expiresAt = action.expiresAt
        self.proposal = proposal
        rows = proposal.rows.enumerated().map { AssistantHoldingRow(index: $0.offset, holding: $0.element) }
        portfolioListID = proposal.portfolioListId
    }

    /// Positions in `rows` of the ticked rows, in order: sent index i is row `keptIndexes[i]`.
    var keptIndexes: [Int] { rows.indices.filter { rows[$0].keep } }

    /// Why a ticked row cannot be sent, or "" (also for rows that are not ticked).
    func problem(at index: Int) -> String {
        rows[index].keep ? rows[index].problem : ""
    }

    var isSettled: Bool { closedMessage != nil || completedMessage != nil }

    /// Ignoring a save in flight, which the view adds.
    var canSave: Bool {
        !isSettled && !keptIndexes.isEmpty && keptIndexes.allSatisfy { rows[$0].problem.isEmpty }
    }

    var confirmBody: AIReviewedHoldings {
        AIReviewedHoldings(
            portfolioListId: portfolioListID,
            replaceExisting: replaceExisting,
            rows: keptIndexes.map { rows[$0].reviewed }
        )
    }

    /// The switch shows once the backend named a collision, and stays while on.
    var showsReplaceToggle: Bool { refusal?.isCollision == true || replaceExisting }

    var saveTitle: String {
        let count = keptIndexes.count
        return count == 1 ? String(localized: "Save 1 holding") : String(localized: "Save \(count) holdings")
    }

    var fromFileText: String {
        proposal.fromCsv
            ? String(localized: "Check each row against your CSV. Only ticked rows are saved.")
            : String(localized: "Check each row against your file. Only ticked rows are saved.")
    }

    /// Places a 422's row errors, which index the sent rows, on `rows`.
    mutating func refuse(_ message: String, isCollision: Bool = false, rowErrors: [AIHoldingRowError]) {
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
        refusal = Refusal(message: message, isCollision: isCollision, byRow: byRow, unplaced: unplaced)
    }
}
