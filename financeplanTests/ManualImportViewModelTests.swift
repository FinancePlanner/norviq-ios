#if canImport(XCTest)
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class ManualImportViewModelTests: XCTestCase {
    func testAddAndRemoveRows() async {
        let vm = ManualImportViewModel(
            bulkCreateStocks: { _ in BulkStockResponse(created: 0, failed: 0, results: []) }
        )
        XCTAssertEqual(vm.entries.count, 1)
        vm.addRow()
        vm.addRow()
        XCTAssertEqual(vm.entries.count, 3)
        vm.removeRows(at: IndexSet([1]))
        XCTAssertEqual(vm.entries.count, 2)
    }

    func testBuildPositions_TrimsUppercasesAndParsesNumbers() async {
        let vm = ManualImportViewModel(
            bulkCreateStocks: { _ in BulkStockResponse(created: 0, failed: 0, results: []) }
        )
        vm.entries = [
            ManualEntry(symbol: "  aapl  ", quantity: "10", price: "150.5"),
            ManualEntry(symbol: "", quantity: "5", price: "100"), // ignored (empty symbol)
            ManualEntry(symbol: "TSLA", quantity: "0", price: "200"), // ignored (qty 0)
            ManualEntry(symbol: "msft", quantity: "1,234.56", price: "2,345.67")
        ]

        let positions = vm.buildPositions()
        XCTAssertEqual(positions.count, 2)
        XCTAssertEqual(positions[0].symbol, "AAPL")
        XCTAssertEqual(positions[0].quantity, 10)
        XCTAssertEqual(positions[0].price, 150.5, accuracy: 0.0001)
        XCTAssertEqual(positions[1].symbol, "MSFT")
        XCTAssertEqual(positions[1].quantity, 1234.56, accuracy: 0.0001)
        XCTAssertEqual(positions[1].price, 2345.67, accuracy: 0.0001)
    }

    func testImportPositions_DelegatesToInjectedService() async throws {
        let recorder = RequestRecorder()
        let vm = ManualImportViewModel(
            bulkCreateStocks: { requests in
                await recorder.set(requests)
                return BulkStockResponse(created: requests.count, failed: 0, results: [])
            }
        )

        try await vm.importPositions(
            [ImportedPosition(symbol: "AAPL", quantity: 3, price: 210.5)],
            buyDate: "2026-04-09"
        )

        let capturedRequests = await recorder.value
        XCTAssertEqual(capturedRequests.count, 1)
        XCTAssertEqual(capturedRequests.first?.symbol, "AAPL")
        XCTAssertEqual(capturedRequests.first?.shares ?? -1, 3, accuracy: 0.0001)
        XCTAssertEqual(capturedRequests.first?.buyPrice ?? -1, 210.5, accuracy: 0.0001)
        XCTAssertEqual(capturedRequests.first?.buyDate, "2026-04-09")
        XCTAssertEqual(capturedRequests.first?.category, .stock)
    }

    func testExpenseBudgetSetupViewModel_UsesInjectedServiceAndSkipsInvalidExpenses() async throws {
        let service = ExpenseBudgetSetupServiceMock()
        let vm = ExpenseBudgetSetupViewModel(expensesService: service)
        vm.monthlyIncome = "5000"
        vm.pillars = [
            .fundamentals: 50,
            .futureYou: 30,
            .fun: 20,
        ]
        vm.expenses = [
            ExpenseEntry(title: "Rent", amount: "1200", pillar: .fundamentals),
            ExpenseEntry(title: "Coffee", amount: "", pillar: .fun), // ignored invalid amount
            ExpenseEntry(title: "", amount: "300", pillar: .futureYou), // ignored blank title
        ]

        try await vm.createBudgetSnapshot()

        XCTAssertEqual(service.snapshotRequests.count, 1)
        XCTAssertEqual(service.expenseRequests.count, 1)
        XCTAssertEqual(service.snapshotRequests[0].netSalary, 5000, accuracy: 0.0001)
        XCTAssertEqual(service.snapshotRequests[0].targetShares["fundamentals"] ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(service.snapshotRequests[0].targetShares["futureYou"] ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(service.snapshotRequests[0].targetShares["fun"] ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(service.expenseRequests[0].title, "Rent")
        XCTAssertEqual(service.expenseRequests[0].amount, 1200, accuracy: 0.0001)
        XCTAssertEqual(service.expenseRequests[0].pillar, .fundamentals)
        XCTAssertEqual(service.expenseRequests[0].splitMode, .personal)
        XCTAssertEqual(service.expenseRequests[0].userSharePercent, 100, accuracy: 0.0001)
    }
}

private final class ExpenseBudgetSetupServiceMock: ExpenseBudgetSetupServicing {
    private(set) var snapshotRequests: [BudgetSnapshotRequest] = []
    private(set) var expenseRequests: [ExpenseRequest] = []

    func createBudgetSnapshot(request: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
        snapshotRequests.append(request)
        return BudgetSnapshotResponse(
            id: UUID().uuidString,
            monthStart: request.monthStart,
            netSalary: request.netSalary,
            targetShares: request.targetShares
        )
    }

    func createExpense(request: ExpenseRequest) async throws -> ExpenseResponse {
        expenseRequests.append(request)
        return ExpenseResponse(
            id: UUID().uuidString,
            title: request.title,
            amount: request.amount,
            pillar: request.pillar,
            occurredOn: request.occurredOn,
            linkedPlanItemId: request.linkedPlanItemId,
            splitMode: request.splitMode,
            userSharePercent: request.userSharePercent
        )
    }
}

private actor RequestRecorder {
    private(set) var value: [StockRequest] = []

    func set(_ requests: [StockRequest]) {
        value = requests
    }
}
#endif
