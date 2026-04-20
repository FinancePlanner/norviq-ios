import SwiftUI
import StockPlanShared

@MainActor
public struct BadgesView: View {
    @StateObject private var viewModel = BadgesViewModel()
    @Environment(\.colorScheme) private var scheme

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.badges.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.badges.isEmpty {
                errorView(error)
            } else {
                badgesContent
            }
        }
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: - Content

    private var badgesContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                badgeGrid
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load() }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background ring (track)
                Circle()
                    .stroke(
                        AppTheme.Colors.tertiaryFill(for: scheme),
                        lineWidth: 10
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: overallProgress)
                    .stroke(
                        AngularGradient(
                            colors: tierGradient,
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: overallProgress)

                VStack(spacing: 2) {
                    Text("\(viewModel.totalEarnedTiers)")
                        .font(.title.bold()).fontDesign(.rounded)
                        .foregroundStyle(.primary)

                    Text("of \(viewModel.totalAvailableTiers)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            VStack(spacing: 4) {
                Text("Achievement Progress")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Complete objectives to earn Bronze, Silver & Gold badges")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.cardBackground(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.separator(for: scheme), lineWidth: 1)
        )
    }

    // MARK: - Badge Grid

    private var badgeGrid: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.badges) { badge in
                badgeCard(badge)
            }
        }
    }

    // MARK: - Badge Card

    private func badgeCard(_ badge: BadgeProgressResponse) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Badge icon
                badgeIcon(badge)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(badge.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        if badge.currentTier == .gold {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(badge.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Tier indicators
                tierIndicators(badge)
            }
            .padding(16)

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.Colors.tertiaryFill(for: scheme))
                            .frame(height: 6)

                        Capsule()
                            .fill(progressGradient(for: badge))
                            .frame(width: geo.size.width * badge.progress, height: 6)
                            .animation(.easeInOut(duration: 0.8), value: badge.progress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(progressLabel(for: badge))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let next = badge.nextTier {
                        Text("\(badge.currentCount)/\(badge.targetCount) to \(next.rawValue.capitalized)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(tierColor(for: next))
                    } else {
                        Text("Complete!")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // Earned tiers row
            if !badge.earnedTiers.isEmpty {
                Divider()
                    .overlay(AppTheme.Colors.separator(for: scheme))

                HStack(spacing: 8) {
                    ForEach(badge.earnedTiers, id: \.tier) { earned in
                        earnedTierPill(earned)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(AppTheme.Colors.cardBackground(for: scheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    badge.currentTier == .gold
                        ? Color.yellow.opacity(0.3)
                        : AppTheme.Colors.separator(for: scheme),
                    lineWidth: badge.currentTier == .gold ? 1.5 : 1
                )
        )
    }

    // MARK: - Components

    private func badgeIcon(_ badge: BadgeProgressResponse) -> some View {
        ZStack {
            Circle()
                .fill(
                    badge.currentTier != nil
                        ? tierColor(for: badge.currentTier!).opacity(0.15)
                        : AppTheme.Colors.tertiaryFill(for: scheme)
                )
                .frame(width: 44, height: 44)

            Image(systemName: badge.iconName)
                .font(.headline)
                .foregroundStyle(
                    badge.currentTier != nil
                        ? tierColor(for: badge.currentTier!)
                        : .secondary
                )
        }
    }

    private func tierIndicators(_ badge: BadgeProgressResponse) -> some View {
        HStack(spacing: 4) {
            ForEach(BadgeTier.allCases, id: \.self) { tier in
                let isEarned = badge.earnedTiers.contains(where: { $0.tier == tier })
                Circle()
                    .fill(isEarned ? tierColor(for: tier) : AppTheme.Colors.tertiaryFill(for: scheme))
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(tierColor(for: tier).opacity(0.3), lineWidth: isEarned ? 0 : 1)
                    )
            }
        }
    }

    private func earnedTierPill(_ earned: EarnedTierInfo) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .typography(.nano, weight: .bold)
            Text(earned.tier.rawValue.capitalized)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tierColor(for: earned.tier))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tierColor(for: earned.tier).opacity(0.12))
        .clipShape(Capsule())
    }

    private func progressLabel(for badge: BadgeProgressResponse) -> String {
        if badge.earnedTiers.isEmpty {
            return "Not started"
        }
        if badge.currentTier == .gold {
            return "All tiers earned"
        }
        return "\(badge.currentTier?.rawValue.capitalized ?? "") earned"
    }

    private func progressGradient(for badge: BadgeProgressResponse) -> LinearGradient {
        let color: Color = {
            if let next = badge.nextTier {
                return tierColor(for: next)
            }
            return .yellow
        }()
        return LinearGradient(
            colors: [color.opacity(0.7), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Tier Colors

    private func tierColor(for tier: BadgeTier) -> Color {
        switch tier {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: return Color(red: 0.65, green: 0.70, blue: 0.75)
        case .gold:   return Color(red: 1.00, green: 0.84, blue: 0.00)
        }
    }

    private var tierGradient: [Color] {
        [
            Color(red: 0.80, green: 0.50, blue: 0.20),
            Color(red: 0.65, green: 0.70, blue: 0.75),
            Color(red: 1.00, green: 0.84, blue: 0.00),
            Color(red: 0.80, green: 0.50, blue: 0.20)
        ]
    }

    private var overallProgress: CGFloat {
        guard viewModel.totalAvailableTiers > 0 else { return 0 }
        return CGFloat(viewModel.totalEarnedTiers) / CGFloat(viewModel.totalAvailableTiers)
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 12) {
                shimmerBlock(height: 170)
                ForEach(0..<4, id: \.self) { _ in
                    shimmerBlock(height: 130)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    private func shimmerBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.Colors.cardBackground(for: scheme))
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                AppTheme.Colors.tertiaryFill(for: scheme),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.load() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
