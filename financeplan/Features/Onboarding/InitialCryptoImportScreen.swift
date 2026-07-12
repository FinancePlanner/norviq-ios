import Factory
import OSLog
import PostHog
import StockPlanShared
import SwiftUI

private let onboardingCryptoLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "OnboardingCrypto"
)

/// Optional, skippable onboarding step where the user picks a few cryptocurrencies
/// to seed their crypto watchlist. Mirrors `InitialStockImportScreen`.
struct InitialCryptoImportScreen: View {
    let onDone: () -> Void
    let onBack: () -> Void
    var headerNamespace: Namespace.ID?

    @State private var assets: [CryptoAssetResponse] = []
    @State private var selected: Set<String> = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var banner: OnboardingStepBanner?

    private let cryptoService: any CryptoServicing = Container.shared.cryptoService()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        OnboardingStepScaffold(
            config: OnboardingStepScaffoldConfig(
                title: "Add Crypto",
                icon: "bitcoinsign.circle.fill",
                namespace: headerNamespace,
                primaryActionTitle: selected.isEmpty ? "Skip for now" : "Add \(selected.count) to watchlist",
                primaryActionAccessibilityIdentifier: "onboarding.cryptoContinueButton",
                isPrimaryActionEnabled: !isSaving,
                isPrimaryActionLoading: isSaving,
                showsPrimaryActionArrow: true
            ),
            onBack: onBack,
            onPrimaryAction: primaryAction,
            banner: banner,
            scrollDismissesKeyboard: .immediately,
            topAccessory: { EmptyView() },
            content: { content },
            footer: { EmptyView() }
        )
        .task { await loadAssets() }
        .onAppear {
            PostHogSDK.shared.capture("onboarding_crypto_step_viewed")
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pick a few coins to watch")
                .typography(.title, weight: .bold)

            Text("Track the coins you care about. You can always change this later — or skip and add them anytime.")
                .typography(.label)
                .foregroundStyle(.secondary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(curatedAssets) { asset in
                        coinChip(asset)
                    }
                }
            }
        }
        .padding(.vertical, 16)
    }

    private var curatedAssets: [CryptoAssetResponse] {
        Array(assets.prefix(16))
    }

    private func coinChip(_ asset: CryptoAssetResponse) -> some View {
        let isSelected = selected.contains(asset.symbol)
        return Button {
            toggle(asset.symbol)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(asset.symbol.prefix(1)))
                            .foregroundStyle(.white)
                            .bold()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(displaySymbol(asset.symbol))
                        .typography(.label, weight: .bold)
                        .lineLimit(1)
                    Text(asset.name)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.Colors.success : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .appGlassEffect(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.Colors.success : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(PressEffectStyle())
    }

    private func displaySymbol(_ symbol: String) -> String {
        symbol.replacingOccurrences(of: "USD", with: "")
    }

    private func toggle(_ symbol: String) {
        if selected.contains(symbol) {
            selected.remove(symbol)
        } else {
            selected.insert(symbol)
        }
    }

    private func loadAssets() async {
        guard assets.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            assets = try await cryptoService.fetchCryptoList()
        } catch {
            onboardingCryptoLogger.error("Failed to load crypto list: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func primaryAction() {
        guard !selected.isEmpty else {
            PostHogSDK.shared.capture("onboarding_crypto_step_skipped")
            onDone()
            return
        }

        isSaving = true
        Task {
            let chosen = curatedAssets.filter { selected.contains($0.symbol) }
            var added = 0
            for asset in chosen {
                do {
                    _ = try await cryptoService.addToWatchlist(
                        payload: CryptoWatchlistItemRequest(
                            symbol: asset.symbol,
                            name: asset.name,
                            note: nil,
                            status: nil
                        )
                    )
                    added += 1
                } catch {
                    onboardingCryptoLogger.error("Failed to add \(asset.symbol, privacy: .public) to watchlist: \(error.localizedDescription, privacy: .public)")
                }
            }
            isSaving = false
            PostHogSDK.shared.capture("onboarding_crypto_step_completed", properties: ["added": added])
            if added == 0 {
                banner = OnboardingStepBanner(
                    message: "Couldn't add coins right now. You can add them later from the Crypto tab.",
                    style: .error
                )
            }
            onDone()
        }
    }
}
