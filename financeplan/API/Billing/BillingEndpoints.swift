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

struct BillingCouponDiscountResponse: Codable, Equatable {
  let percentage: Int?
  let amount: Int?
  let currency: String?
}

struct BillingCouponResponse: Codable, Equatable {
  let code: String
  let grantType: String
  let trialDays: Int
  let discount: BillingCouponDiscountResponse
  let expiresAt: Date?
}

struct BillingCouponRedemptionResponse: Codable, Equatable {
  let coupon: BillingCouponResponse
  let trialDaysRemaining: Int?
  let isTrialActive: Bool
  let billingContext: BillingContextResponse?
}
