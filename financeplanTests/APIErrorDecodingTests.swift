import XCTest
@testable import financeplan

@MainActor
final class APIErrorDecodingTests: XCTestCase {
  func testDecodesStandardEnvelopeReason() async {
    await Task.yield()
    let data = #"{"error":true,"code":"bad_request","reason":"Symbol is required.","requestId":"req-1"}"#
      .data(using: .utf8)!

    XCTAssertEqual(APIErrorDecoding.message(from: data), "Symbol is required.")
  }

  func testDecodesLegacyStringError() async {
    await Task.yield()
    let data = #"{"error":"Token expired"}"#.data(using: .utf8)!

    XCTAssertEqual(APIErrorDecoding.message(from: data), "Token expired")
  }

  func testDecodesVaporReason() async {
    await Task.yield()
    let data = #"{"error":true,"reason":"Username already registered"}"#.data(using: .utf8)!

    XCTAssertEqual(APIErrorDecoding.message(from: data), "Username already registered")
  }
}
