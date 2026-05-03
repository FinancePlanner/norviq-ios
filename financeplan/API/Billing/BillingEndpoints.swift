import AnyAPI
import Foundation
import StockPlanShared

struct GetBillingContextEndpoint: Endpoint {
  typealias Response = BillingContextResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/billing/me" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct RestoreBillingEndpoint: Endpoint {
  typealias Response = BillingContextResponse

  var method: HTTPMethod { .post }
  var path: String { "/v1/billing/restore" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct RedeemBillingCouponEndpoint: Endpoint {
  typealias Response = BillingCouponRedemptionResponse

  let code: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/billing/coupons/redeem" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["code": code]
  }
}

struct BillingCouponDiscountResponse: Codable, Equatable, Sendable {
  let percentage: Int?
  let amount: Int?
  let currency: String?

  nonisolated func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(percentage, forKey: .percentage)
    try c.encodeIfPresent(amount, forKey: .amount)
    try c.encodeIfPresent(currency, forKey: .currency)
  }
}

struct BillingCouponResponse: Codable, Equatable, Sendable {
  let code: String
  let grantType: String
  let trialDays: Int
  let discount: BillingCouponDiscountResponse
  let expiresAt: Date?

  nonisolated func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(code, forKey: .code)
    try c.encode(grantType, forKey: .grantType)
    try c.encode(trialDays, forKey: .trialDays)
    try c.encode(discount, forKey: .discount)
    try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
  }
}

struct BillingCouponRedemptionResponse: Equatable, Sendable {
  let coupon: BillingCouponResponse
  let trialDaysRemaining: Int?
  let isTrialActive: Bool
  let billingContext: BillingContextResponse?

  nonisolated func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(coupon, forKey: .coupon)
    try c.encodeIfPresent(trialDaysRemaining, forKey: .trialDaysRemaining)
    try c.encode(isTrialActive, forKey: .isTrialActive)
    try c.encodeIfPresent(billingContext, forKey: .billingContext)
  }
}

nonisolated extension BillingCouponRedemptionResponse: Codable {}
