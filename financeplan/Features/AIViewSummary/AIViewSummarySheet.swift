import StockPlanShared
import SwiftUI

/// The sheet a screen's AI button opens.
///
/// Reads as an answer, not a chat: no composer, nothing to type. "Continue in
/// Q" is there for when the reader wants to go further, and is the only route
/// out into the assistant.
struct AIViewSummarySheet: View {
    let scope: AIViewScope
    let onContinueInQ: (String) -> Void

    @State private var viewModel = AIViewSummaryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            .vigilScreenBackground()
            .vigilNavigationTitle(scope.displayName.capitalizedFirstLetter)
            .vigilInlineNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh(scope: scope) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Regenerate")
                    .disabled(viewModel.state == .loading)
                }
            }
            .safeAreaInset(edge: .bottom) { continueInQ }
        }
        .presentationDetents([.medium, .large])
        .task { await viewModel.loadIfNeeded(scope: scope) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            // A spinner rather than a shimmer or a redaction: those imply a
            // known shape arriving, and until the text lands there is no shape.
            VStack(spacing: 12) {
                ProgressView()
                Text("Analyzing your \(scope.displayName)…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)

        case let .loaded(summary):
            GlassCard(cornerRadius: 18, padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(summary.title)
                        .font(.headline)
                    Text(summary.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !summary.highlights.isEmpty {
                        AIHighlightRows(highlights: summary.highlights)
                    }

                    Text(summary.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    // Says plainly when this was written. The server caches for
                    // an hour, so without this a reader could take an old
                    // sentence for a live one.
                    Text(summary.generatedAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

        case let .failed(message):
            ErrorRetryView(message: message) {
                Task { await viewModel.refresh(scope: scope) }
            }
            .padding(.vertical, 32)
        }
    }

    @ViewBuilder
    private var continueInQ: some View {
        if case .loaded = viewModel.state {
            Button {
                onContinueInQ(scope.followUpPrompt)
            } label: {
                Label("Continue in Q", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .accessibilityIdentifier("aiSummary.continueInQ.\(scope.rawValue)")
        }
    }
}

private extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
