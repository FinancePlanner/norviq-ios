import Foundation
import Testing
@testable import StockPlanShared

@Test func authLoginRequestRoundTripJSON() throws {
    let payload = AuthLoginRequest(email: "user@example.com", password: "secret")

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(AuthLoginRequest.self, from: encoded)

    #expect(decoded == payload)
}

@Test func authRegisterRequestRoundTripJSON() throws {
    let payload = AuthRegisterRequest(
        username: "valid_user",
        password: "Password123!",
        confirmPassword: "Password123!",
        email: "user@example.com",
        dateOfBirth: Date(timeIntervalSince1970: 946_684_800)
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(AuthRegisterRequest.self, from: encoded)

    #expect(decoded == payload)
}

@Test func stockResponseRoundTripJSON() throws {
    let payload = StockResponse(
        id: "stock-id",
        symbol: "AAPL",
        shares: 10,
        buyPrice: 150.25,
        buyDate: "2026-01-10",
        notes: "Starter position",
        createdAt: "2026-01-10T00:00:00Z"
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(StockResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func goalStatusUpdateRequestRoundTripJSON() throws {
    let payload = GoalStatusUpdateRequest(status: .completed, source: .manual)

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(GoalStatusUpdateRequest.self, from: encoded)

    #expect(decoded == payload)
}

@Test func goalResponseRoundTripJSON() throws {
    let payload = GoalResponse(
        id: "goal-id",
        title: "Review watchlist before earnings",
        status: .pending,
        statusUpdatedBy: .manual,
        completedAt: nil,
        createdAt: "2026-04-08T10:00:00Z",
        updatedAt: "2026-04-08T10:00:00Z"
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(GoalResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func apiSuccessRoundTripJSON() throws {
    let payload = APISuccess(success: true)

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(APISuccess.self, from: encoded)

    #expect(decoded == payload)
}

@Test func apiEnvelopeRoundTripJSON() throws {
    let auth = try AuthResponse(
        token: "jwt-token",
        userId: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
        expiresIn: 604_800,
        refreshToken: "refresh-token",
        refreshExpiresIn: 2_592_000,
        username: "valid_user",
        email: "user@example.com",
        dateOfBirth: Date(timeIntervalSince1970: 946_684_800)
    )

    let payload = APIEnvelope(success: true, data: auth, message: "ok")

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(APIEnvelope<AuthResponse>.self, from: encoded)

    #expect(decoded == payload)
}

@Test func stockPlanSharedDecoderDecodesAuthResponseEncodedAsReferenceDateNumber() throws {
    let payload = try AuthResponse(
        token: "jwt-token",
        userId: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
        expiresIn: 604_800,
        refreshToken: "refresh-token",
        refreshExpiresIn: 2_592_000,
        username: "valid_user",
        email: "user@example.com",
        dateOfBirth: Date(timeIntervalSince1970: 946_684_800)
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder.stockPlanShared.decode(AuthResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func stockPlanSharedDecoderDecodesSnakeCaseDBStyleDateString() throws {
    let payload = """
    {
      "token": "jwt-token",
      "user_id": "00000000-0000-0000-0000-000000000001",
      "expires_in": 604800,
      "refresh_token": "refresh-token",
      "refresh_expires_in": 2592000,
      "username": "valid_user",
      "email": "user@example.com",
      "date_of_birth": "2000-01-01"
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder.stockPlanShared.decode(AuthResponse.self, from: payload)

    #expect(decoded.userId == UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    #expect(decoded.dateOfBirth == DateFormatter.yyyyMMdd.date(from: "2000-01-01"))
}

@Test func stockPlanSharedDecoderDecodesSnakeCaseOAuthDTOs() throws {
    let startPayload = """
    {
      "flow_id": "00000000-0000-0000-0000-000000000002",
      "authorization_url": "https://oauth.example.test/auth",
      "expires_in": 600
    }
    """.data(using: .utf8)!

    let start = try JSONDecoder.stockPlanShared.decode(OAuthStartResponse.self, from: startPayload)
    #expect(start.flowId == UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
    #expect(start.authorizationURL == "https://oauth.example.test/auth")
    #expect(start.expiresIn == 600)

    let exchangePayload = """
    {
      "flow_id": "00000000-0000-0000-0000-000000000002",
      "code": "code-123",
      "state": "state-123",
      "redirect_uri": "norviqa://oauth/callback"
    }
    """.data(using: .utf8)!

    let exchange = try JSONDecoder.stockPlanShared.decode(OAuthExchangeRequest.self, from: exchangePayload)
    #expect(exchange.redirectURI == "norviqa://oauth/callback")
}

@Test func bulkStockRequestRoundTripJSON() throws {
    let payload = BulkStockRequest(stocks: [
        StockRequest(
            symbol: "AAPL", shares: 10.5, buyPrice: 150.25, buyDate: "2026-01-10", notes: "First"
        ),
        StockRequest(
            symbol: "MSFT", shares: 5, buyPrice: 300.00, buyDate: "2026-02-15", notes: nil
        ),
    ])

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(BulkStockRequest.self, from: encoded)

    #expect(decoded == payload)
}

@Test func bulkStockResponseRoundTripJSON() throws {
    let payload = BulkStockResponse(
        created: 1,
        failed: 1,
        results: [
            BulkStockResultItem(
                index: 0,
                stock: StockResponse(
                    id: "id-1", symbol: "AAPL", shares: 10.5, buyPrice: 150.25,
                    buyDate: "2026-01-10", notes: nil, createdAt: "2026-01-10T00:00:00Z"
                )
            ),
            BulkStockResultItem(index: 1, error: "Invalid buyDate. Expected YYYY-MM-DD."),
        ]
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(BulkStockResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func bulkStockRequestEmptyArray() throws {
    let payload = BulkStockRequest(stocks: [])

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(BulkStockRequest.self, from: encoded)

    #expect(decoded == payload)
    #expect(decoded.stocks.isEmpty)
}

@Test func userProfileResponseRoundTripJSON() throws {
    let profile = UserProfile(
        id: "user-id",
        email: "user@example.com",
        bio: "Investor",
        avatarURL: URL(string: "https://example.com/avatar.png"),
        bannerAvatarURL: URL(string: "https://example.com/banner.png"),
        username: "investor_1"
    )
    let payload = GetUserProfileResponse(userProfile: profile)

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(GetUserProfileResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func updateUserProfileRequestRoundTripJSON() throws {
    let profile = UserProfile(
        id: "user-id",
        email: "user@example.com",
        bio: "Long-term investor",
        avatarURL: nil,
        bannerAvatarURL: nil,
        username: "valueinvestor"
    )
    let payload = UpdateUserProfileRequest(userProfile: profile)

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(UpdateUserProfileRequest.self, from: encoded)

    #expect(decoded == payload)
}

@Test func deleteUserProfileResponseRoundTripJSON() throws {
    let payload = DeleteUserProfileResponse(success: true, message: "Profile deleted")

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(DeleteUserProfileResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func reportsCashFlowPointResponseRoundTripJSON() throws {
    let payload = ReportsCashFlowPointResponse(
        monthStart: "2026-04-01",
        income: 3000,
        expenses: 2200,
        net: 800,
        savingsRate: 26.67
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(ReportsCashFlowPointResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func reportsOverviewResponseRoundTripJSON() throws {
    let payload = ReportsOverviewResponse(
        generatedAt: "2026-04-08T10:00:00Z",
        portfolioStatistics: ImportedStocksStatisticsDTO(
            totalPositions: 0,
            totalMarketValue: 0,
            totalCostBasis: 0,
            totalUnrealizedPnl: 0,
            totalRealizedPnl: 0,
            stockSummaries: [],
            stockAllocations: [],
            sectorAllocations: [],
            calendarPerformance: []
        ),
        monthlySummaries: [],
        yearlySummaries: [],
        latestMonthSummary: nil,
        latestPillarSummaries: [],
        cashFlow: [
            ReportsCashFlowPointResponse(
                monthStart: "2026-04-01",
                income: 3000,
                expenses: 2000,
                net: 1000,
                savingsRate: 33.33
            ),
        ]
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(ReportsOverviewResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func reportSuggestionResponseRoundTripJSON() throws {
    let payload = ReportSuggestionResponse(
        id: "overspend-2026-04-01-18",
        title: "Spending exceeded plan",
        message: "You spent 18% above plan this month.",
        severity: .high,
        category: .overspend,
        monthStart: "2026-04-01",
        recommendedSavings: 320,
        detailPayload: [
            "planned": "1800.00",
            "actual": "2120.00",
        ]
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(ReportSuggestionResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func budgetPillarSupportsCustomValues() throws {
    let pillar = try #require(BudgetPillar(rawValue: "Nuclear Theme"))
    #expect(pillar.rawValue == "nuclearTheme")

    let encoded = try JSONEncoder().encode(pillar)
    let decoded = try JSONDecoder().decode(BudgetPillar.self, from: encoded)
    #expect(decoded == pillar)
}

@Test func expenseRequestRoundTripWithCustomPillar() throws {
    let pillar = try #require(BudgetPillar(rawValue: "Semi Conductors"))
    let payload = ExpenseRequest(
        title: "ASML buy",
        amount: 120,
        pillar: pillar,
        occurredOn: "2026-04-11"
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(ExpenseRequest.self, from: encoded)
    #expect(decoded == payload)
    #expect(decoded.pillar.rawValue == "semiConductors")
}

@Test func billingContextResponseRoundTripJSON() throws {
    let generatedAt = Date(timeIntervalSince1970: 1_776_700_800)
    let periodStart = Date(timeIntervalSince1970: 1_774_108_800)
    let subscription = BillingSubscriptionDTO(
        provider: "revenuecat",
        store: "app_store",
        productId: "pro_monthly",
        plan: "pro",
        status: "active",
        periodStartedAt: periodStart,
        periodEndsAt: Date(timeIntervalSince1970: 1_779_292_800),
        trialEndsAt: nil,
        gracePeriodEndsAt: nil,
        cancelledAt: nil,
        isTrial: false,
        isInGracePeriod: false,
        hasBillingIssue: false,
        isCancelledButActive: false,
        renewsOrExpiresAt: Date(timeIntervalSince1970: 1_779_292_800),
        willRenew: true,
        accessEndsAt: Date(timeIntervalSince1970: 1_779_292_800),
        pendingProductId: "pro_annual",
        pendingPlan: "pro_annual",
        pendingPlanEffectiveAt: Date(timeIntervalSince1970: 1_779_292_800)
    )
    let payload = BillingContextResponse(
        plan: "pro",
        entitlementLevel: "pro",
        isPro: true,
        isPremium: true,
        subscription: subscription,
        planOptions: [
            BillingPlanOptionDTO(
                productId: "pro_annual",
                plan: "pro_annual",
                displayName: "Annual",
                interval: "annual",
                rank: 3,
                badge: "Best value",
                isCurrent: false,
                changeKind: "upgrade"
            ),
        ],
        features: [
            BillingFeatureDTO(
                key: "advancedResearch",
                title: "Advanced stock research",
                available: true,
                requiredPlan: nil,
                reason: nil,
                limit: nil,
                used: nil,
                remaining: nil
            ),
        ],
        usage: [
            BillingUsageDTO(
                key: "csvImports",
                used: 2,
                limit: 10,
                remaining: 8,
                periodStart: periodStart
            ),
        ],
        generatedAt: generatedAt
    )

    let encoded = try JSONEncoder.stockPlanShared.encode(payload)
    let decoded = try JSONDecoder.stockPlanShared.decode(BillingContextResponse.self, from: encoded)

    #expect(decoded == payload)
}

@Test func billingContextResponseDecodesBackendJSON() throws {
    let payload = """
    {
      "plan": "free",
      "entitlementLevel": "free",
      "isPro": false,
      "isPremium": false,
      "subscription": null,
      "features": [
        {
          "key": "advancedResearch",
          "title": "Advanced stock research",
          "available": false,
          "requiredPlan": "pro",
          "reason": "Upgrade to Pro to use Advanced stock research.",
          "limit": null,
          "used": null,
          "remaining": null
        }
      ],
      "usage": [
        {
          "key": "csvImports",
          "used": 1,
          "limit": 3,
          "remaining": 2,
          "periodStart": "2026-04-01T00:00:00Z"
        }
      ],
      "generatedAt": "2026-04-21T12:00:00Z"
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder.stockPlanShared.decode(BillingContextResponse.self, from: payload)

    #expect(decoded.plan == "free")
    #expect(decoded.entitlementLevel == "free")
    #expect(decoded.isPro == false)
    #expect(decoded.isPremium == false)
    #expect(decoded.subscription == nil)
    #expect(decoded.planOptions.isEmpty)
    #expect(decoded.features.first?.requiredPlan == "pro")
    #expect(decoded.usage.first?.remaining == 2)
}

@Test func billingUpgradeRequiredResponseRoundTripJSON() throws {
    let payload = BillingUpgradeRequiredResponse(
        success: false,
        code: "upgrade_required",
        error: "Upgrade to Pro to create more target alerts.",
        feature: "targetAlerts",
        plan: "free",
        requiredPlan: "pro",
        limit: 3,
        current: 3
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(BillingUpgradeRequiredResponse.self, from: encoded)

    #expect(decoded == payload)
}
