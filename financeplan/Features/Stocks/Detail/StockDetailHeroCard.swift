import StockPlanShared
import SwiftUI

struct StockDetailHeroCard: View {
    let details: StockDetails?
    let companyProfile: CompanyProfileResponse?
    let comparisonProfile: StockComparisonProfile?
    let marketSnapshot: StockMarketSnapshot?

    @Environment(\.colorScheme) private var colorScheme

    private var displayPrice: Double? {
        marketSnapshot?.currentPrice ?? comparisonProfile?.currentPrice
    }

    private var positionMarketValue: Double? {
        guard let details, let displayPrice else { return nil }
        return details.shares * displayPrice
    }

    private var costBasis: Double? {
        guard let details else { return nil }
        return details.shares * details.buyPrice
    }

    private var symbolText: String {
        companyProfile?.displayTicker ?? comparisonProfile?.symbol ?? details?.symbol ?? "Stock"
    }

    private var companyNameText: String {
        companyProfile?.displayName ?? comparisonProfile?.companyName ?? "Waiting for company profile"
    }

    private var summaryText: String? {
        var values: [String] = []

        if let exchange = companyProfile?.exchange?.trimmingCharacters(in: .whitespacesAndNewlines),
           !exchange.isEmpty {
            values.append(exchange)
        }

        if let industry = companyProfile?.finnhubIndustry?.trimmingCharacters(in: .whitespacesAndNewlines),
           !industry.isEmpty {
            values.append(industry)
        }

        if let country = companyProfile?.localizedCountryName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !country.isEmpty {
            values.append(country)
        }

        return values.isEmpty ? nil : values.joined(separator: " • ")
    }

    var body: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    StockCompanyAvatarView(
                        companyProfile: companyProfile,
                        fallbackText: symbolText,
                        colorScheme: colorScheme
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(symbolText)
                            .typography(.hero, weight: .bold)

                        Text(companyNameText)
                            .typography(.small)
                            .foregroundStyle(.secondary)

                        if let summaryText {
                            Text(summaryText)
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                        }

                        if let details {
                            Text("Purchased \(details.buyDate) • \(details.shares.formatted(.number.precision(.fractionLength(0...2)))) shares")
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                HStack(alignment: .top, spacing: 10) {
                    HeroMetricPill(
                        title: "Current price",
                        value: displayPrice?.currency ?? "Pending",
                        tint: AppTheme.Colors.tint(for: colorScheme)
                    )
                    HeroMetricPill(
                        title: "Position",
                        value: positionMarketValue?.currency ?? "Pending",
                        tint: AppTheme.Colors.success
                    )
                    HeroMetricPill(
                        title: "Cost basis",
                        value: costBasis?.currency ?? "Pending",
                        tint: AppTheme.Colors.warning
                    )
                }

                if let companyProfile {
                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            DetailItem(title: "Exchange", value: companyProfile.exchange ?? "—")
                            DetailItem(title: "Industry", value: companyProfile.finnhubIndustry ?? "—")
                        }

                        GridRow {
                            DetailItem(title: "Country", value: companyProfile.localizedCountryName ?? "—")
                            DetailItem(title: "IPO", value: companyProfile.ipo ?? "—")
                        }

                        GridRow {
                            DetailItem(title: "Currency", value: companyProfile.currency ?? "—")
                            DetailItem(title: "Estimate currency", value: companyProfile.estimateCurrency ?? "—")
                        }

                        GridRow {
                            DetailItem(
                                title: "Market cap",
                                value: companyProfile.marketCapitalizationAmount.map { StockMetricFormatter.compactCurrency($0) } ?? "—"
                                )
                                DetailItem(
                                title: "Shares outstanding",
                                value: companyProfile.sharesOutstandingAmount.map { StockMetricFormatter.compactNumber($0) } ?? "—"
                                )                        }

                        GridRow {
                            DetailItem(title: "Phone", value: companyProfile.phone ?? "—")
                            CompanyProfileWebsiteItem(companyProfile: companyProfile)
                        }
                    }
                }
            }
        }
    }
}
