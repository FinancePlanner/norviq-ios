import Factory
import StockPlanShared
import SwiftUI

struct StockEarningsTab: View {
    let symbol: String
    let earnings: [EarningsEvent]
    let isLoading: Bool
    let errorMessage: String?
    let selectedTranscript: EarningsTranscript?
    let isTranscriptLoading: Bool
    let transcriptErrorMessage: String?
    let onSelectTranscript: (EarningsEvent) -> Void
    let onDismissTranscript: () -> Void

    @State private var transcriptEvent: EarningsEvent?

    var body: some View {
        VStack(spacing: 24) {
            if isLoading && earnings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let errorMessage {
                ResearchPlaceholderCard(
                    title: String(localized: "earnings.error.title", defaultValue: "Earnings error"),
                    bodyText: errorMessage
                )
            } else if earnings.isEmpty {
                ResearchPlaceholderCard(title: "No earnings data", bodyText: "No data found for \(symbol).")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Earnings History")
                        .typography(.label, weight: .bold)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        EarningsTableHeader()

                        ForEach(Array(earnings.enumerated()), id: \.element.id) { index, event in
                            if event.hasTranscript == true {
                                Button {
                                    transcriptEvent = event
                                    onSelectTranscript(event)
                                } label: {
                                    EarningsTableRow(
                                        event: event,
                                        isLast: index == earnings.count - 1,
                                        isTranscriptLoading: isTranscriptLoading && transcriptEvent?.id == event.id
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                EarningsTableRow(
                                    event: event,
                                    isLast: index == earnings.count - 1,
                                    isTranscriptLoading: false
                                )
                            }
                        }
                    }
                    .appGlassEffect(.rect(cornerRadius: 24))
                }
            }
        }
        .sheet(item: $transcriptEvent, onDismiss: onDismissTranscript) { event in
            EarningsTranscriptSheet(
                event: event,
                transcript: selectedTranscript,
                isLoading: isTranscriptLoading,
                errorMessage: transcriptErrorMessage
            )
        }
    }
}

// MARK: - Components

struct EarningsTableHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Date")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("EPS")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Revenue")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Surprise")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .typography(.nano, weight: .semibold)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

struct EarningsTableRow: View {
    let event: EarningsEvent
    let isLast: Bool
    let isTranscriptLoading: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDisplayDate(event.date))
                        .typography(.caption, weight: .bold)
                    if event.hasTranscript == true {
                        HStack(spacing: 6) {
                            Label("Transcript", systemImage: "text.page")
                                .labelStyle(.titleAndIcon)
                            if isTranscriptLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .typography(.nano, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Transcript available")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                EarningsMetricCell(
                    primary: formattedEPS(event.epsActual),
                    secondary: "Est \(formattedEPS(event.epsEstimated))"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                EarningsMetricCell(
                    primary: formattedRevenue(event.revenueActual),
                    secondary: "Est \(formattedRevenue(event.revenueEstimated))"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedSurprisePercent)
                        .typography(.caption, weight: .bold)
                        .foregroundStyle(statusColor)
                    Text(surpriseText)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.horizontal, 20)
            }
        }
    }

    private var statusColor: Color {
        guard let surprisePercent = resolvedSurprisePercent else { return .secondary }
        return surprisePercent >= 0 ? .green : .red
    }

    private var surpriseText: String {
        guard let surprisePercent = resolvedSurprisePercent else { return "Reported" }
        return surprisePercent >= 0 ? "Beat" : "Miss"
    }

    private var formattedSurprisePercent: String {
        guard let surprisePercent = resolvedSurprisePercent else { return "—" }
        let formatted = abs(surprisePercent).formatted(.number.precision(.fractionLength(1)))
        return surprisePercent >= 0 ? "+\(formatted)%" : "-\(formatted)%"
    }

    private var resolvedSurprisePercent: Double? {
        if let surprisePercent = event.surprisePercent {
            return surprisePercent
        }
        guard let act = event.epsActual, let est = event.epsEstimated, est != 0 else { return nil }
        return ((act - est) / abs(est)) * 100
    }

    private func formatDisplayDate(_ rawDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(rawDate.prefix(10))) else { return rawDate }
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formattedEPS(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func formattedRevenue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.notation(.compactName))
    }
}

struct EarningsTranscriptSheet: View {
    let event: EarningsEvent
    let transcript: EarningsTranscript?
    let isLoading: Bool
    let errorMessage: String?

    @InjectedObservable(\Container.earningsAudioPlayer) private var audioPlayer

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && transcript == nil && errorMessage == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ResearchPlaceholderCard(
                        title: String(localized: "earnings.transcript.error.title", defaultValue: "Transcript error"),
                        bodyText: errorMessage
                    )
                    .padding()
                } else if let transcript {
                    ScrollView {
                        Text(transcript.content)
                            .typography(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                    }
                } else {
                    ResearchPlaceholderCard(
                        title: String(localized: "earnings.transcript.unavailable.title", defaultValue: "Transcript unavailable"),
                        bodyText: String(
                            format: String(
                                localized: "earnings.transcript.unavailable.body",
                                defaultValue: "No transcript found for %1$@ on %2$@."
                            ),
                            event.symbol,
                            formatDisplayDate(event.date)
                        )
                    )
                    .padding()
                }
            }
            .navigationTitle(
                String(
                    format: String(
                        localized: "earnings.transcript.navtitle",
                        defaultValue: "%@ Transcript"
                    ),
                    event.symbol
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let transcript {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            audioPlayer.toggle(transcript)
                        } label: {
                            Label(
                                audioPlayer.isPlaying(transcript)
                                    ? String(localized: "earnings.transcript.pause", defaultValue: "Pause")
                                    : String(localized: "earnings.transcript.listen", defaultValue: "Listen"),
                                systemImage: audioPlayer.isPlaying(transcript)
                                    ? "pause.circle.fill"
                                    : "play.circle.fill"
                            )
                            .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
        }
    }

    private func formatDisplayDate(_ rawDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(rawDate.prefix(10))) else { return rawDate }
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct EarningsMetricCell: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(primary)
                .typography(.caption, weight: .semibold)
            Text(secondary)
                .typography(.nano)
                .foregroundStyle(.secondary)
        }
    }
}

struct FinancialStatementsIntroCard: View {
    let symbol: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Financial statements")
                            .typography(.small, weight: .semibold)

                        Text("Review balance sheet strength and cash generation for \(symbol) when statement data is available.")
                            .typography(.small)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

struct FinancialStatementPeriodPicker: View {
    @Binding var selectedPeriod: StockFinancialStatementPeriod
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Statement period")
                    .typography(.small, weight: .semibold)

                Text("Switch between single filings or grouped annual and quarterly views.")
                    .typography(.nano)
                    .foregroundStyle(.secondary)

                GlassEffectContainer(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StockFinancialStatementPeriod.allCases) { period in
                                Button {
                                    withAnimation(.snappy(duration: 0.22)) {
                                        selectedPeriod = period
                                    }
                                } label: {
                                    Text(period.title)
                                        .typography(.caption, weight: .semibold)
                                        .foregroundStyle(selectedPeriod == period ? .primary : .secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .glassEffect(
                                            selectedPeriod == period
                                                ? .regular.tint(AppTheme.Colors.tint(for: colorScheme)).interactive()
                                                : .regular.interactive(),
                                            in: .capsule
                                        )
                                        .glassEffectID(period.id, in: selectionNamespace)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}
