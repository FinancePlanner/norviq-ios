import StockPlanShared
import SwiftUI

/// Switch plus the feeds the user follows on top of the curated list.
struct NewsTickerSettingsView: View {
  @Bindable var viewModel: NewsTickerViewModel
  @State private var feeds: [NewsTickerFeed] = []
  @State private var maxFeeds = 10
  @State private var newFeedURL = ""
  @State private var isAdding = false
  @State private var feedError: String?

  private let service: any NewsTickerServicing = Container.shared.newsTickerService()

  init(viewModel: NewsTickerViewModel = NewsTickerViewModel()) {
    self.viewModel = viewModel
  }

  var body: some View {
    Form {
      Section {
        Toggle(isOn: Binding(
          get: { viewModel.isEnabled },
          set: { value in Task { await viewModel.setEnabled(value) } }
        )) {
          Text(LocalizedStringKey("Show breaking news"))
        }
      } footer: {
        Text(LocalizedStringKey("Headlines from publishers' own feeds on your dashboard. Links open the publisher; nothing is stored beyond the headline."))
      }

      Section {
        ForEach(feeds) { feed in
          VStack(alignment: .leading, spacing: 2) {
            if let title = feed.title, !title.isEmpty {
              Text(title).typography(.small, weight: .semibold)
            }
            Text(feed.url).typography(.nano).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        .onDelete { offsets in
          Task { await remove(at: offsets) }
        }

        if feeds.count < maxFeeds {
          HStack {
            TextField(LocalizedStringKey("Site or feed address"), text: $newFeedURL)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .keyboardType(.URL)
            Button {
              Task { await add() }
            } label: {
              if isAdding { ProgressView() } else { Text(LocalizedStringKey("Add")) }
            }
            .disabled(isAdding || newFeedURL.trimmingCharacters(in: .whitespaces).isEmpty)
          }
        }
      } header: {
        Text(LocalizedStringKey("Your feeds"))
      } footer: {
        if let feedError {
          Text(feedError).foregroundStyle(.red)
        } else {
          Text("\(feeds.count) of \(maxFeeds) used. Norviq finds the feed behind a site address.")
        }
      }

      if let error = viewModel.errorMessage {
        Section {
          Text(error).foregroundStyle(.red)
        }
      }
    }
    .navigationTitle(Text(LocalizedStringKey("News ticker")))
    .task { await loadFeeds() }
  }

  private func loadFeeds() async {
    guard let response = try? await service.listFeeds() else { return }
    feeds = response.feeds
    maxFeeds = response.maxFeeds
  }

  private func add() async {
    isAdding = true
    defer { isAdding = false }
    feedError = nil
    do {
      let added = try await service.addFeed(url: newFeedURL.trimmingCharacters(in: .whitespaces))
      feeds.append(added)
      newFeedURL = ""
      await viewModel.refresh()
    } catch {
      feedError = error.localizedDescription
    }
  }

  private func remove(at offsets: IndexSet) async {
    for index in offsets.sorted(by: >) {
      let feed = feeds[index]
      do {
        try await service.removeFeed(id: feed.id)
        feeds.remove(at: index)
      } catch {
        feedError = error.localizedDescription
      }
    }
    await viewModel.refresh()
  }
}
