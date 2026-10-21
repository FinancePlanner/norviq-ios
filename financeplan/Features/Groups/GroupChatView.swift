import Factory
import StockPlanShared
import SwiftUI
import UIKit

/// A channel's messages and the composer.
struct GroupChatView: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @Environment(\.scenePhase) private var scenePhase
  let detail: GroupDetail
  let onInvite: () -> Void
  @State private var model: GroupChatModel
  @State private var draft = ""
  @State private var presenceToken: UUID?
  @State private var reportTarget: BoardReportTarget?
  @State private var blockUsername: String?
  @State private var deleteTarget: GroupChatMessage?
  @State private var isAtBottom = true
  @FocusState private var isComposerFocused: Bool

  init(detail: GroupDetail, channel: GroupChannel, onInvite: @escaping () -> Void) {
    self.detail = detail
    self.onInvite = onInvite
    _model = State(initialValue: GroupChatModel(
      groupID: detail.group.id,
      channel: channel,
      currentUsername: Container.shared.boardsViewerStore().username
    ))
  }

  private static let bottomID = "chat-bottom"

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          if model.hasMoreBefore {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding()
              .task { await model.loadOlder() }
          } else if model.hasLoaded {
            channelIntro
          }
          ForEach(model.rows()) { row in
            rowView(row)
              .id(row.id)
          }
          Color.clear.frame(height: 1).id(Self.bottomID)
            .onAppear { isAtBottom = true }
            .onDisappear { isAtBottom = false }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
      }
      .defaultScrollAnchor(.bottom)
      .scrollDismissesKeyboard(.interactively)
      .overlay(alignment: .bottomTrailing) {
        if !isAtBottom {
          Button {
            withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
          } label: {
            Label("Jump to latest", systemImage: "arrow.down")
              .labelStyle(.iconOnly)
              .padding(10)
              .background(.regularMaterial, in: Circle())
          }
          .padding(12)
          .accessibilityLabel("Jump to latest")
        }
      }
      .overlay(alignment: .top) { noticeBanner }
      .safeAreaInset(edge: .bottom) { bottomBar }
      .onChange(of: model.messages.last?.id) { _, _ in
        guard isAtBottom || model.messages.last?.authorId == model.currentUserID else { return }
        withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        if scenePhase == .active { model.scheduleMarkRead() }
      }
    }
    .environment(\.openURL, OpenURLAction { url in
      guard let symbol = TickerChipParser.symbol(from: url) else { return .systemAction }
      NotificationCenter.default.post(name: .openStockFromPushNotification, object: nil, userInfo: ["symbol": symbol])
      return .handled
    })
    .task {
      presenceToken = store.chatDidAppear(model)
      if !model.hasLoaded {
        await model.load()
        model.scheduleMarkRead()
      }
    }
    .onDisappear {
      if let presenceToken { store.chatDidDisappear(token: presenceToken) }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task {
        await model.catchUp()
        model.scheduleMarkRead()
      }
    }
    .sheet(item: $reportTarget) { BoardReportSheet(target: $0) }
    .confirmationDialog(
      "Block \(blockUsername ?? "")?",
      isPresented: Binding(get: { blockUsername != nil }, set: { if !$0 { blockUsername = nil } }),
      titleVisibility: .visible
    ) {
      Button("Block", role: .destructive) {
        guard let username = blockUsername else { return }
        Task { await block(username) }
      }
    } message: {
      Text("You won't see each other's messages, posts or comments, and any friendship ends.")
    }
    .confirmationDialog(
      "Delete this message?",
      isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        guard let message = deleteTarget else { return }
        Task { await model.delete(message) }
      }
    }
    .alert("Something went wrong", isPresented: errorAlertBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  // MARK: Rows

  @ViewBuilder
  private func rowView(_ row: GroupChatRow) -> some View {
    switch row {
    case let .day(date):
      Text(date.formatted(.dateTime.weekday(.wide).month().day()))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    case .newMessages:
      HStack(spacing: 8) {
        Rectangle().fill(Color.red).frame(height: 1)
        Text("New messages").font(.caption2.weight(.bold)).foregroundStyle(.red)
      }
      .padding(.vertical, 6)
      .accessibilityElement(children: .combine)
    case let .message(message, showsHeader):
      GroupMessageRow(message: message, showsHeader: showsHeader)
        .contextMenu { menu(for: message) }
        .onTapGesture {
          if case .failed = message.state { model.retry(message) }
        }
    }
  }

  @ViewBuilder
  private func menu(for message: GroupChatMessage) -> some View {
    if let body = message.body, !message.isDeleted {
      Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = body }
    }
    if case .failed = message.state {
      Button("Try again", systemImage: "arrow.clockwise") { model.retry(message) }
      Button("Discard", systemImage: "trash", role: .destructive) { model.discard(message) }
    }
    if let serverID = message.serverID, !message.isDeleted {
      let isOwn = message.authorId != nil && message.authorId == model.currentUserID
      if !isOwn {
        Button("Report", systemImage: "flag") {
          reportTarget = .groupMessage(serverID, excerpt: message.body ?? "")
        }
        if let username = message.authorUsername {
          Button("Block @\(username)", systemImage: "hand.raised") { blockUsername = username }
        }
      }
      if isOwn || detail.permissions.canModerate {
        Button("Delete", systemImage: "trash", role: .destructive) { deleteTarget = message }
      }
    }
  }

  private var channelIntro: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Welcome to #\(model.channel.name)").font(.title3.weight(.bold))
      if let topic = model.channel.topic, !topic.isEmpty {
        Text(topic).font(.subheadline).foregroundStyle(.secondary)
      } else {
        Text("This is the start of #\(model.channel.name) in \(detail.group.name).")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      if detail.permissions.canInvite, detail.group.memberCount < 3 {
        Button("Invite friends", systemImage: "person.badge.plus", action: onInvite)
          .buttonStyle(.bordered)
          .padding(.top, 4)
      }
    }
    .padding(.vertical, 16)
  }

  // MARK: Composer

  @ViewBuilder
  private var bottomBar: some View {
    if detail.group.membership == nil {
      Text("Join this group to read and chat.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding()
        .background(.bar)
    } else if !detail.permissions.canPost || !viewer.canWrite {
      VStack {
        BoardsViewerBanner()
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(.bar)
    } else {
      HStack(alignment: .bottom, spacing: 8) {
        TextField("Message #\(model.channel.name)", text: $draft, axis: .vertical)
          .lineLimit(1...6)
          .focused($isComposerFocused)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
          .accessibilityIdentifier("groups.composer")
        Button {
          model.send(draft)
          draft = ""
        } label: {
          Image(systemName: "arrow.up.circle.fill").font(.title)
        }
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 2000)
        .accessibilityLabel("Send")
        .accessibilityIdentifier("groups.send")
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(.bar)
    }
  }

  @ViewBuilder
  private var noticeBanner: some View {
    if let notice = model.notice {
      Label(notice, systemImage: "exclamationmark.bubble")
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .task(id: notice) {
          try? await Task.sleep(for: .seconds(4))
          model.notice = nil
        }
    }
  }

  private func block(_ username: String) async {
    do {
      try await Container.shared.boardsService().block(username: username)
      model.hideMessages(by: username)
    } catch {
      model.errorMessage = error.localizedDescription
    }
  }
}

/// One message: name and time at the start of a run, then the body with
/// tickers as links. Deleted messages keep their place as a tombstone.
struct GroupMessageRow: View {
  let message: GroupChatMessage
  let showsHeader: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if showsHeader {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(message.authorUsername.map { "@\($0)" } ?? String(localized: "Deleted user"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tint)
          Text(message.createdAt.formatted(date: .omitted, time: .shortened))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
      }
      if message.isDeleted {
        Text("Message deleted")
          .font(.body.italic())
          .foregroundStyle(.secondary)
      } else if let body = message.body {
        Text(TickerChipParser.attributed(body, tint: AppTheme.Colors.tint))
          .font(.body)
          .textSelection(.enabled)
          .opacity(message.state == .sending ? 0.55 : 1)
      }
      if case .failed = message.state {
        Label("Not sent. Tap to try again.", systemImage: "exclamationmark.circle")
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 1)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
