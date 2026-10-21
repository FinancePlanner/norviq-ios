import Factory
import StockPlanShared
import SwiftUI

// MARK: - Create

/// One form: topic, ticker (for stocks, ETFs and crypto), name, emoji,
/// description and who can join. The community guidelines come first for
/// anyone who hasn't accepted them.
struct CreateGroupSheet: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @InjectedObservable(\Container.socialStore) private var socialStore
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @Environment(\.dismiss) private var dismiss
  let onCreated: (GroupDetail) -> Void
  @State private var topic: GroupTopic = .stock
  @State private var ticker = ""
  @State private var name = ""
  @State private var nameEdited = false
  @State private var emoji: String?
  @State private var description = ""
  @State private var visibility: GroupVisibility = .private
  @State private var isSubmitting = false
  @State private var errorMessage: String?
  @State private var showGuidelines = false

  static let topics: [GroupTopic] = [.stock, .etf, .crypto, .community, .custom]
  static let emojis = ["📈", "💰", "🚀", "🏦", "🌱", "🪙", "🔋", "🛢️", "🏠", "🤝", "🎯", "💬"]

  var body: some View {
    NavigationStack {
      Form {
        Section("What's it about?") {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(Self.topics, id: \.self) { option in
                Button(option.title) {
                  topic = option
                  if !option.allowsTicker { ticker = "" }
                  suggestName()
                }
                .buttonStyle(.bordered)
                .tint(topic == option ? AppTheme.Colors.tint : .secondary)
                .accessibilityAddTraits(topic == option ? .isSelected : [])
              }
            }
          }
          if topic.allowsTicker {
            TextField("Ticker, e.g. AAPL", text: $ticker)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .onChange(of: ticker) { _, value in
                let normalized = Self.normalizedTicker(value)
                if normalized != value { ticker = normalized }
                suggestName()
              }
              .accessibilityIdentifier("groups.create.ticker")
          }
        }
        Section {
          TextField("Name", text: Binding(get: { name }, set: { name = $0; nameEdited = true }))
            .accessibilityIdentifier("groups.create.name")
          TextField("What's it for? (optional)", text: $description, axis: .vertical)
            .lineLimit(2...4)
        }
        Section("Icon") {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
            ForEach(Self.emojis, id: \.self) { option in
              Button {
                emoji = emoji == option ? nil : option
              } label: {
                Text(option)
                  .font(.title2)
                  .frame(width: 40, height: 40)
                  .background(
                    emoji == option ? AppTheme.Colors.tint.opacity(0.2) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                  )
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(emoji == option ? .isSelected : [])
            }
          }
        }
        Section {
          Picker("Who can join", selection: $visibility) {
            Text("Invite only").tag(GroupVisibility.private)
            if socialStore.config.groupsPublic {
              Text("Anyone").tag(GroupVisibility.public)
            }
          }
        } footer: {
          Text(visibility == .private
            ? "Only people you invite can find and read this group."
            : "Anyone on Norviq can find this group and join. Up to 3 new groups a day.")
        }
        if let errorMessage {
          Section { Text(errorMessage).foregroundStyle(.red) }
        }
      }
      .navigationTitle("New group")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { Task { await submit() } }
            .disabled(!canSubmit)
            .accessibilityIdentifier("groups.create.submit")
        }
      }
      .task {
        if viewer.status == nil { await viewer.load() }
        if viewer.needsGuidelines { showGuidelines = true }
      }
      .sheet(isPresented: $showGuidelines) { BoardsGuidelinesSheet() }
    }
  }

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  private var canSubmit: Bool {
    (2...50).contains(trimmedName.count)
      && (!topic.allowsTicker || ticker.isEmpty || ticker.count <= 12)
      && !isSubmitting
      && !viewer.needsGuidelines
  }

  private func suggestName() {
    guard !nameEdited else { return }
    name = ticker.isEmpty ? "" : String(localized: "$\(ticker) holders")
  }

  /// "$aapl " → "AAPL".
  static func normalizedTicker(_ raw: String) -> String {
    let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
    return String(raw.uppercased().filter { allowed.contains($0) }.prefix(12))
  }

  private func submit() async {
    if viewer.needsGuidelines {
      showGuidelines = true
      return
    }
    isSubmitting = true
    defer { isSubmitting = false }
    let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      let detail = try await store.create(
        CreateGroupRequest(
          name: trimmedName,
          description: trimmedDescription.isEmpty ? nil : trimmedDescription,
          iconEmoji: emoji,
          topic: topic,
          ticker: topic.allowsTicker && !ticker.isEmpty ? ticker : nil,
          visibility: visibility
        )
      )
      dismiss()
      onCreated(detail)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

extension GroupTopic {
  var title: String {
    switch self {
    case .stock: String(localized: "Stock")
    case .etf: String(localized: "ETF")
    case .crypto: String(localized: "Crypto")
    case .community: String(localized: "Community")
    case .custom, .other: String(localized: "Anything")
    }
  }
}

// MARK: - Join with a link

/// Opened by an invite link, or by "Join with a link" with a pasted one:
/// shows the group and who invited, then joins.
struct GroupJoinSheet: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @Environment(\.dismiss) private var dismiss
  let initialCode: String?
  let onJoined: (GroupDetail) -> Void
  @State private var input = ""
  @State private var preview: GroupInvitePreview?
  @State private var isWorking = false
  @State private var errorMessage: String?

  private let service: any GroupsServicing = Container.shared.groupsService()

  var body: some View {
    NavigationStack {
      Form {
        if let preview {
          Section {
            HStack(spacing: 12) {
              GroupIcon(emoji: preview.group.iconEmoji, name: preview.group.name, size: 52)
              VStack(alignment: .leading, spacing: 4) {
                Text(preview.group.name).font(.title3.weight(.semibold))
                Text("^[\(preview.group.memberCount) member](inflect: true)")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
            if !preview.group.description.isEmpty {
              Text(preview.group.description).font(.subheadline)
            }
            if let inviter = preview.inviterUsername {
              Label("@\(inviter) invited you", systemImage: "person.crop.circle.badge.checkmark")
                .font(.subheadline)
            }
          }
          Section {
            Button(preview.alreadyMember ? "Open group" : "Join group") {
              Task { await join(code: preview.code) }
            }
            .disabled(isWorking)
            .accessibilityIdentifier("groups.join.submit")
          }
        } else {
          Section {
            TextField("Paste an invite link or code", text: $input)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
          } footer: {
            Text("Invite links look like norviq.org/g/…")
          }
          Section {
            Button("Continue") { Task { await loadPreview(Self.code(from: input)) } }
              .disabled(Self.code(from: input) == nil || isWorking)
          }
        }
        if let errorMessage {
          Section { Text(errorMessage).foregroundStyle(.red) }
        }
      }
      .navigationTitle("Join a group")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
      .task {
        if let initialCode, preview == nil { await loadPreview(initialCode) }
      }
    }
  }

  /// A full link (either form) or a bare code.
  static func code(from text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url = URL(string: trimmed), case let .invite(code) = GroupDeepLink.parse(url) { return code }
    if let url = URL(string: "https://\(trimmed)"), case let .invite(code) = GroupDeepLink.parse(url) { return code }
    return SocialDeepLink.normalizedCode(trimmed)
  }

  private func loadPreview(_ code: String?) async {
    guard let code else { return }
    isWorking = true
    defer { isWorking = false }
    do {
      preview = try await service.invitePreview(code: code)
      errorMessage = nil
    } catch {
      errorMessage = Self.message(for: error)
    }
  }

  private func join(code: String) async {
    isWorking = true
    defer { isWorking = false }
    do {
      let detail = try await store.redeem(code: code)
      dismiss()
      onJoined(detail)
    } catch {
      errorMessage = Self.message(for: error)
    }
  }

  static func message(for error: Error) -> String {
    switch (error as? GroupsHTTPClient.Error)?.code {
    case "invite_expired": String(localized: "This invite has expired. Ask for a new one.")
    case "invite_exhausted": String(localized: "This invite has been used up. Ask for a new one.")
    case "group_not_found": String(localized: "This invite isn't valid any more.")
    case "group_banned": String(localized: "You can't join this group.")
    case "group_full": String(localized: "This group is full.")
    default: error.localizedDescription
    }
  }
}

// MARK: - Invite

/// Friends to invite directly, and a link to share anywhere else.
struct GroupInviteSheet: View {
  @InjectedObservable(\Container.socialStore) private var socialStore
  @Environment(\.dismiss) private var dismiss
  let group: GroupSummary
  @State private var selected: Set<String> = []
  @State private var invited: Set<String> = []
  @State private var link: GroupInviteLink?
  @State private var isWorking = false
  @State private var errorMessage: String?

  private let service: any GroupsServicing = Container.shared.groupsService()

  var body: some View {
    NavigationStack {
      List {
        Section("Friends") {
          if socialStore.friends.isEmpty {
            Text("Friends you add on Norviq show up here.").foregroundStyle(.secondary)
          }
          ForEach(socialStore.friends) { friend in
            Button {
              toggle(friend.id)
            } label: {
              SocialUserRow(user: friend) {
                if invited.contains(friend.id) {
                  Text("Invited").font(.caption).foregroundStyle(.secondary)
                } else {
                  Image(systemName: selected.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(friend.id) ? AppTheme.Colors.tint : .secondary)
                }
              }
            }
            .buttonStyle(.plain)
            .disabled(invited.contains(friend.id))
          }
          if !selected.isEmpty {
            Button("Invite ^[\(selected.count) friend](inflect: true)") { Task { await inviteSelected() } }
              .disabled(isWorking)
              .accessibilityIdentifier("groups.invite.send")
          }
        }
        Section("Or share a link") {
          if let link, let url = URL(string: link.url) {
            InviteLinkShareSection(
              url: url,
              subject: Text("Join \(group.name) on Norviq"),
              message: String(localized: "Join my group \(group.name) on Norviq: \(url.absoluteString)"),
              qrLabel: Text("QR code for the group invite link")
            )
            .padding(.vertical, 8)
            if let expiresAt = link.expiresAt {
              Text("Expires \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          } else {
            Button("Create invite link", systemImage: "link") { Task { await createLink() } }
              .disabled(isWorking)
          }
        }
        if let errorMessage {
          Section { Text(errorMessage).foregroundStyle(.red) }
        }
      }
      .navigationTitle("Invite to \(group.name)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .task {
        if !socialStore.hasLoaded { await socialStore.load() }
      }
    }
  }

  private func toggle(_ id: String) {
    if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
  }

  private func inviteSelected() async {
    isWorking = true
    defer { isWorking = false }
    do {
      let response = try await service.inviteFriends(groupId: group.id, userIds: selected.compactMap(UUID.init(uuidString:)))
      let done = Set(response.invitedUserIds.map { $0.uuidString })
      invited.formUnion(selected.filter { done.contains($0.uppercased()) || done.contains($0) })
      selected.removeAll()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func createLink() async {
    isWorking = true
    defer { isWorking = false }
    do {
      link = try await service.createInviteLink(groupId: group.id, .default)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
