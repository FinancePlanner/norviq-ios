import Factory
import StockPlanShared
import SwiftUI

@MainActor
struct MarketNewsScreen: View {
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var model = ThesisWatchViewModel()
  @State private var isPaywallPresented = false

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        introduction
        scopePicker

        if model.capabilities?.isPro == false {
          proBanner
        }

        content
      }
      .padding(16)
    }
    .navigationTitle("Thesis Watch")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          guard model.capabilities?.isPro == true else {
            isPaywallPresented = true
            return
          }
          Task { await model.setNotificationsEnabled(!model.notificationsEnabled) }
        } label: {
          Image(systemName: model.notificationsEnabled ? "bell.fill" : "bell")
        }
        .accessibilityLabel(model.notificationsEnabled ? "Disable Thesis Watch alerts" : "Enable Thesis Watch alerts")
      }
    }
    .refreshable { await model.load(force: true) }
    .task { await model.load() }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("News measured against what you own")
        .typography(.headline, weight: .bold)
      Text(
        "Stories are clustered, ranked by your exposure, and checked against the risks and catalysts in your research notes."
      )
      .typography(.caption)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var scopePicker: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(ThesisWatchScope.allCases, id: \.self) { scope in
          Button {
            Task { await model.selectScope(scope) }
          } label: {
            Text(scope.title)
              .typography(.caption, weight: .semibold)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(model.scope == scope ? Color.accentColor : Color.secondary.opacity(0.12))
              .foregroundStyle(model.scope == scope ? Color.white : Color.primary)
              .clipShape(.capsule)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  private var proBanner: some View {
    Button {
      isPaywallPresented = true
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "sparkles")
          .foregroundStyle(.yellow)
        VStack(alignment: .leading, spacing: 2) {
          Text("Unlock portfolio impact")
            .typography(.headline, weight: .semibold)
          Text("Pro adds exposure ranking, thesis checks, and high-signal alerts.")
            .typography(.nano)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(.secondary)
      }
      .padding()
      .appGlassEffect(.rect(cornerRadius: 16))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var content: some View {
    if model.isLoading, model.stories.isEmpty {
      ProgressView("Building your news brief…")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    } else if let errorMessage = model.errorMessage, model.stories.isEmpty {
      ContentUnavailableView {
        Label("Couldn’t load Thesis Watch", systemImage: "exclamationmark.triangle")
      } description: {
        Text(errorMessage)
      } actions: {
        Button("Try Again") { Task { await model.load(force: true) } }
      }
    } else if model.stories.isEmpty {
      ContentUnavailableView {
        Label("No material stories yet", systemImage: "newspaper")
      } description: {
        Text("Add holdings or watchlist symbols, then check back after the next news refresh.")
      }
    } else {
      ForEach(model.stories) { story in
        ThesisWatchStoryCard(
          story: story,
          onOpen: { Task { await model.markRead(story) } },
          onFeedback: { signal in Task { await model.sendFeedback(signal, for: story) } }
        )
      }

      if model.nextCursor != nil {
        Button {
          Task { await model.loadMore() }
        } label: {
          if model.isLoadingMore {
            ProgressView()
          } else {
            Text("Load more")
          }
        }
        .disabled(model.isLoadingMore)
      }
    }
  }
}

private struct ThesisWatchStoryCard: View {
  let story: ThesisWatchStory
  let onOpen: () -> Void
  let onFeedback: (ThesisWatchFeedbackSignal) -> Void
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Label(story.relationship.title, systemImage: story.relationship.icon)
        Text(story.eventType.title)
        Spacer()
        severityBadge
      }
      .typography(.nano, weight: .semibold)
      .foregroundStyle(.secondary)

      Text(story.headline)
        .typography(.headline, weight: .semibold)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let summary = story.summary ?? story.providerSummary, !summary.isEmpty {
        Text(summary)
          .typography(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(4)
      }

      if let whyItMatters = story.whyItMatters {
        VStack(alignment: .leading, spacing: 4) {
          Text("WHY IT MATTERS")
            .typography(.nano, weight: .bold)
            .foregroundStyle(.secondary)
          Text(whyItMatters)
            .typography(.caption, weight: .medium)
        }
        .padding(12)
        .background(impactColor.opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
      }

      HStack {
        if !story.symbols.isEmpty {
          Text(story.symbols.joined(separator: " · "))
            .typography(.caption, weight: .bold)
        }
        if let exposure = story.exposure {
          Text("\(exposure.weightPercent, format: .number.precision(.fractionLength(1)))% exposure")
            .typography(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if story.thesisImpact != .notAssessed {
          Label(story.thesisImpact.title, systemImage: story.thesisImpact.icon)
            .typography(.caption, weight: .semibold)
            .foregroundStyle(impactColor)
        }
      }

      Divider()

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(story.source ?? "Financial news")
            .typography(.nano, weight: .semibold)
          Text(story.publishedAt.thesisWatchRelativeDate)
            .typography(.nano)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Menu {
          Button("Relevant", systemImage: "hand.thumbsup") { onFeedback(.relevant) }
          Button("Not relevant", systemImage: "hand.thumbsdown") { onFeedback(.notRelevant) }
          Button("Supports thesis", systemImage: "arrow.up.right") { onFeedback(.supports) }
          Button("Challenges thesis", systemImage: "exclamationmark.triangle") { onFeedback(.challenges) }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        Button("Read source") {
          guard let url = URL(string: story.url) else { return }
          onOpen()
          openURL(url)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(16)
    .appGlassEffect(.rect(cornerRadius: 18))
    .opacity(story.isRead ? 0.78 : 1)
  }

  private var severityBadge: some View {
    Text(story.severity.rawValue.uppercased())
      .foregroundStyle(story.severity == .high ? Color.red : Color.secondary)
  }

  private var impactColor: Color {
    switch story.thesisImpact {
    case .supports: .green
    case .challenges: .orange
    default: .accentColor
    }
  }
}

private extension ThesisWatchScope {
  var title: String {
    switch self {
    case .forYou: "For You"
    case .holdings: "Holdings"
    case .watchlist: "Watchlist"
    case .sectors: "Sectors"
    case .market: "Market"
    }
  }
}

private extension ThesisWatchRelationship {
  var title: String {
    rawValue.capitalized
  }

  var icon: String {
    self == .holding ? "briefcase.fill" : self == .watchlist ? "eye.fill" : "globe"
  }
}

private extension ThesisWatchEventType {
  var title: String {
    rawValue.replacingOccurrences(of: "_", with: " ").capitalized
  }
}

private extension ThesisWatchImpact {
  var title: String {
    rawValue.replacingOccurrences(of: "_", with: " ").capitalized
  }

  var icon: String {
    self == .supports ? "arrow.up.right" : self == .challenges ? "exclamationmark.triangle.fill" : "minus"
  }
}

private extension String {
  var thesisWatchRelativeDate: String {
    guard let date = try? Date(self, strategy: .iso8601) else { return self }
    return date.formatted(.relative(presentation: .named))
  }
}
