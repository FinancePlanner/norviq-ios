import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

// MARK: - URL Protocol Mock

private final class MockURLProtocol: URLProtocol {
  nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = MockURLProtocol.handler else {
      fatalError("MockURLProtocol.handler must be set before use")
    }
    do {
      let (data, response) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

// MARK: - Tests

@MainActor
final class ExpensesHTTPClientTests: XCTestCase {
  nonisolated(unsafe) private var session: URLSession!
  nonisolated(unsafe) private var baseURL: URL!
  nonisolated(unsafe) private var client: ExpensesHTTPClient!

  override func setUp() {
    super.setUp()
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    session = URLSession(configuration: config)
    baseURL = URL(string: "https://api.example.com")!
    client = ExpensesHTTPClient(baseURL: baseURL, session: session)
  }

  override func tearDown() {
    MockURLProtocol.handler = nil
    session = nil
    client = nil
    super.tearDown()
  }

  private func jsonBody(from request: URLRequest) throws -> [String: Any] {
    if let body = request.httpBody {
      return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    guard let stream = request.httpBodyStream else {
      XCTFail("Expected request body in httpBody or httpBodyStream")
      return [:]
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 4096
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while stream.hasBytesAvailable {
      let readCount = stream.read(&buffer, maxLength: bufferSize)
      if readCount < 0 {
        throw stream.streamError ?? URLError(.cannotDecodeRawData)
      }
      if readCount == 0 {
        break
      }
      data.append(buffer, count: readCount)
    }

    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  // MARK: - Create Expense

  func testCreateExpense_SendsCorrectSnakeCasePayload() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/expenses")

      let json = try self.jsonBody(from: request)

      // Verify snake_case keys (the bug fix)
      XCTAssertEqual(json["title"] as? String, "Groceries")
      XCTAssertEqual(json["amount"] as? Double, 87.50)
      XCTAssertEqual(json["pillar"] as? String, "fundamentals")
      XCTAssertEqual(json["occurred_on"] as? String, "2026-04-05")
      XCTAssertEqual(json["split_mode"] as? String, "personal")
      XCTAssertEqual(json["user_share_percent"] as? Double, 100)

      // Verify camelCase keys are NOT present
      XCTAssertNil(json["occurredOn"])
      XCTAssertNil(json["splitMode"])
      XCTAssertNil(json["userSharePercent"])

      let response = ExpenseResponse(
        id: UUID().uuidString, title: "Groceries", amount: 87.50,
        pillar: .fundamentals, occurredOn: "2026-04-05",
        linkedPlanItemId: nil, splitMode: .personal, userSharePercent: 100,
        createdAt: nil, updatedAt: nil
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.createExpense(
      request: ExpenseRequest(
        title: "Groceries", amount: 87.50,
        pillar: .fundamentals, occurredOn: "2026-04-05"
      )
    )

    XCTAssertEqual(result.title, "Groceries")
    XCTAssertEqual(result.amount, 87.50)
    XCTAssertEqual(result.pillar, .fundamentals)
    XCTAssertEqual(result.splitMode, .personal)
  }

  func testCreateExpense_SharedSplitMode_EncodesCorrectly() async throws {
    MockURLProtocol.handler = { request in
      let json = try self.jsonBody(from: request)

      XCTAssertEqual(json["split_mode"] as? String, "shared")
      XCTAssertEqual(json["user_share_percent"] as? Double, 35)
      XCTAssertEqual(json["linked_plan_item_id"] as? String, "AABBCCDD-1111-2222-3333-444455556666")

      let response = ExpenseResponse(
        id: UUID().uuidString, title: "Rent", amount: 1800,
        pillar: .fundamentals, occurredOn: "2026-04-01",
        linkedPlanItemId: "AABBCCDD-1111-2222-3333-444455556666",
        splitMode: .shared, userSharePercent: 35,
        createdAt: nil, updatedAt: nil
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.createExpense(
      request: ExpenseRequest(
        title: "Rent", amount: 1800,
        pillar: .fundamentals, occurredOn: "2026-04-01",
        linkedPlanItemId: "AABBCCDD-1111-2222-3333-444455556666",
        splitMode: .shared, userSharePercent: 35
      )
    )

    XCTAssertEqual(result.splitMode, .shared)
    XCTAssertEqual(result.userSharePercent, 35)
    XCTAssertEqual(result.linkedPlanItemId, "AABBCCDD-1111-2222-3333-444455556666")
  }

  // MARK: - Create Plan Item (Pillar)

  func testCreatePlanItem_SendsCorrectSnakeCasePayload() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/budget/items")

      let json = try self.jsonBody(from: request)

      // Verify snake_case keys
      XCTAssertEqual(json["snapshot_id"] as? String, "snap-123")
      XCTAssertEqual(json["title"] as? String, "ETF Monthly")
      XCTAssertEqual(json["planned_amount"] as? Double, 400)
      XCTAssertEqual(json["pillar"] as? String, "futureYou")
      XCTAssertEqual(json["split_mode"] as? String, "personal")
      XCTAssertEqual(json["user_share_percent"] as? Double, 100)

      // Verify camelCase keys are NOT present
      XCTAssertNil(json["snapshotId"])
      XCTAssertNil(json["plannedAmount"])
      XCTAssertNil(json["splitMode"])
      XCTAssertNil(json["userSharePercent"])

      let response = BudgetPlanItemResponse(
        id: UUID().uuidString, snapshotId: "snap-123", title: "ETF Monthly", plannedAmount: 400,
        pillar: .futureYou,
        splitMode: .personal, userSharePercent: 100,
        createdAt: nil, updatedAt: nil
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.createPlanItem(
      payload: BudgetPlanItemRequest(
        snapshotId: "snap-123", title: "ETF Monthly",
        plannedAmount: 400, pillar: .futureYou
      )
    )

    XCTAssertEqual(result.title, "ETF Monthly")
    XCTAssertEqual(result.plannedAmount, 400)
    XCTAssertEqual(result.pillar, .futureYou)
  }

  func testCreatePlanItem_SharedSplit_EncodesCorrectPercentage() async throws {
    MockURLProtocol.handler = { request in
      let json = try self.jsonBody(from: request)

      XCTAssertEqual(json["split_mode"] as? String, "shared")
      XCTAssertEqual(json["user_share_percent"] as? Double, 60)

      let response = BudgetPlanItemResponse(
        id: UUID().uuidString, snapshotId: "snap-456", title: "Mortgage", plannedAmount: 2000,
        pillar: .fundamentals,
        splitMode: .shared, userSharePercent: 60,
        createdAt: nil, updatedAt: nil
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.createPlanItem(
      payload: BudgetPlanItemRequest(
        snapshotId: "snap-456", title: "Mortgage",
        plannedAmount: 2000, pillar: .fundamentals,
        splitMode: .shared, userSharePercent: 60
      )
    )

    XCTAssertEqual(result.splitMode, .shared)
    XCTAssertEqual(result.userSharePercent, 60)
  }

  // MARK: - Update Expense

  func testUpdateExpense_SendsSnakeCasePayload() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "PATCH")
      XCTAssertTrue(request.url?.path.contains("/v1/expenses/") == true)

      let json = try self.jsonBody(from: request)

      XCTAssertEqual(json["split_mode"] as? String, "shared")
      XCTAssertEqual(json["user_share_percent"] as? Double, 70)
      XCTAssertNil(json["splitMode"])

      let response = ExpenseResponse(
        id: "exp-999", title: "Updated", amount: 200,
        pillar: .fun, occurredOn: "2026-04-10",
        linkedPlanItemId: nil, splitMode: .shared, userSharePercent: 70,
        createdAt: nil, updatedAt: nil
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.updateExpense(
      expenseId: "exp-999",
      payload: ExpenseRequest(
        title: "Updated", amount: 200,
        pillar: .fun, occurredOn: "2026-04-10",
        splitMode: .shared, userSharePercent: 70
      )
    )

    XCTAssertEqual(result.splitMode, .shared)
    XCTAssertEqual(result.userSharePercent, 70)
  }

  // MARK: - Create Snapshot

  func testCreateSnapshot_SendsSnakeCasePayload() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/budget/snapshots")

      let json = try self.jsonBody(from: request)

      XCTAssertEqual(json["month_start"] as? String, "2026-05-01")
      XCTAssertEqual(json["net_salary"] as? Double, 4500)
      XCTAssertEqual((json["target_shares"] as? [String: Double])?["fundamentals"], 0.5)
      XCTAssertNil(json["monthStart"])
      XCTAssertNil(json["netSalary"])
      XCTAssertNil(json["targetShares"])

      let response = BudgetSnapshotResponse(
        id: UUID().uuidString, monthStart: "2026-05-01",
        netSalary: 4500, targetShares: ["fundamentals": 0.5]
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.createBudgetSnapshot(
      request: BudgetSnapshotRequest(
        monthStart: "2026-05-01", netSalary: 4500,
        targetShares: ["fundamentals": 0.5]
      )
    )

    XCTAssertEqual(result.netSalary, 4500)
  }

  func testUpdateSnapshot_SendsSnakeCasePayload() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "PATCH")
      XCTAssertEqual(request.url?.path, "/v1/budget/snapshots/snap-123")

      let json = try self.jsonBody(from: request)

      XCTAssertEqual(json["month_start"] as? String, "2026-05-01")
      XCTAssertEqual(json["net_salary"] as? Double, 5000)
      XCTAssertEqual((json["target_shares"] as? [String: Double])?["futureYou"], 0.4)
      XCTAssertNil(json["monthStart"])
      XCTAssertNil(json["netSalary"])
      XCTAssertNil(json["targetShares"])

      let response = BudgetSnapshotResponse(
        id: "snap-123", monthStart: "2026-05-01",
        netSalary: 5000, targetShares: ["futureYou": 0.4]
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.updateSnapshot(
      snapshotId: "snap-123",
      payload: BudgetSnapshotRequest(
        monthStart: "2026-05-01", netSalary: 5000, targetShares: ["futureYou": 0.4]
      )
    )

    XCTAssertEqual(result.id, "snap-123")
    XCTAssertEqual(result.netSalary, 5000)
  }

  // MARK: - Suggestions

  func testGetReportSuggestions_DecodesResponse() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v1/reports/suggestions")

      let response = ReportSuggestionsResponse(
        generatedAt: "2026-04-08T12:00:00Z",
        suggestions: [
          ReportSuggestionResponse(
            id: "overspend-2026-04-01-16",
            title: "Spending exceeded plan",
            message: "You spent 16% above plan.",
            severity: .high,
            category: .overspend,
            monthStart: "2026-04-01",
            recommendedSavings: 220,
            detailPayload: ["planned": "1200.00", "actual": "1420.00"]
          )
        ]
      )
      let data = try JSONEncoder.stockPlanShared.encode(response)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.getReportSuggestions(from: nil, to: nil)
    XCTAssertEqual(result.suggestions.count, 1)
    XCTAssertEqual(result.suggestions.first?.category, .overspend)
    XCTAssertEqual(result.suggestions.first?.severity, .high)
  }

  func testDismissReportSuggestion_CallsDismissEndpoint() async throws {
    MockURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/reports/suggestions/overspend-2026-04-01-16/dismiss")

      let payload = APISuccess(success: true)
      let data = try JSONEncoder.stockPlanShared.encode(payload)
      return (data, HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
      )!)
    }

    let result = try await client.dismissReportSuggestion(id: "overspend-2026-04-01-16")
    XCTAssertTrue(result.success)
  }

  // MARK: - Error Handling

  func testCreateExpense_ServerError_ThrowsAPIError() async throws {
    MockURLProtocol.handler = { request in
      let errorBody = #"{"error":"Pillar not found"}"#.data(using: .utf8)!
      return (errorBody, HTTPURLResponse(
        url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil
      )!)
    }

    do {
      _ = try await client.createExpense(
        request: ExpenseRequest(
          title: "Bad", amount: 1, pillar: .fun, occurredOn: "2026-04-01"
        )
      )
      XCTFail("Expected error")
    } catch let error as ExpensesHTTPClient.Error {
      XCTAssertEqual(error, .api("Pillar not found"))
    }
  }

  func testCreateExpense_Unauthorized_ThrowsUnauthorized() async throws {
    MockURLProtocol.handler = { request in
      let errorBody = #"{"error":"Token expired"}"#.data(using: .utf8)!
      return (errorBody, HTTPURLResponse(
        url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil
      )!)
    }

    do {
      _ = try await client.createExpense(
        request: ExpenseRequest(
          title: "Auth test", amount: 1, pillar: .fun, occurredOn: "2026-04-01"
        )
      )
      XCTFail("Expected unauthorized error")
    } catch let error as ExpensesHTTPClient.Error {
      XCTAssertEqual(error, .unauthorized("Token expired"))
    }
  }
}
