import Factory
import StockPlanShared
import SwiftUI

// MARK: - Report

enum BoardReportTarget: Identifiable {
  case post(UUID, title: String)
  case comment(UUID, excerpt: String)

  var id: UUID {
    switch self {
    case let .post(id, _), let .comment(id, _): return id
    }
  }

  var request: (postId: UUID?, commentId: UUID?) {
    switch self {
    case let .post(id, _): return (id, nil)
    case let .comment(id, _): return (nil, id)
    }
  }

  var summary: String {
    switch self {
    case let .post(_, title): return title
    case let .comment(_, excerpt): return excerpt
    }
  }
}

extension BoardReportReason {
  var title: String {
    switch self {
    case .spam: return String(localized: "Spam")
    case .harassment: return String(localized: "Harassment or bullying")
    case .hate: return String(localized: "Hate speech")
    case .scam: return String(localized: "Scam or pump-and-dump")
    case .impersonation: return String(localized: "Impersonation")
    case .inappropriate: return String(localized: "Sexual or violent content")
    case .other: return String(localized: "Something else")
    }
  }
}

struct BoardReportSheet: View {
  let target: BoardReportTarget
  @Environment(\.dismiss) private var dismiss
  @State private var reason: BoardReportReason?
  @State private var note = ""
  @State private var isSubmitting = false
  @State private var didSubmit = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        if didSubmit {
          Section {
            Label("Thanks. We review every report within 24 hours.", systemImage: "checkmark.shield")
          }
        } else {
          Section {
            Text(target.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
          }
          Section("Why are you reporting this?") {
            ForEach(BoardReportReason.allCases, id: \.self) { option in
              Button {
                reason = option
              } label: {
                HStack {
                  Text(option.title).foregroundStyle(.primary)
                  Spacer()
                  if reason == option {
                    Image(systemName: "checkmark").foregroundStyle(AppTheme.Colors.tint)
                  }
                }
              }
            }
          }
          Section("Details (optional)") {
            TextField("What happened?", text: $note, axis: .vertical).lineLimit(3...6)
          }
          if let errorMessage {
            Section { Text(errorMessage).foregroundStyle(.red) }
          }
        }
      }
      .navigationTitle("Report")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(didSubmit ? "Done" : "Cancel") { dismiss() }
        }
        if !didSubmit {
          ToolbarItem(placement: .confirmationAction) {
            Button("Send") { Task { await submit() } }
              .disabled(reason == nil || isSubmitting)
          }
        }
      }
    }
  }

  private func submit() async {
    guard let reason else { return }
    isSubmitting = true
    defer { isSubmitting = false }
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      try await Container.shared.boardsService().report(
        BoardReportRequest(
          postId: target.request.postId,
          commentId: target.request.commentId,
          reason: reason,
          note: trimmed.isEmpty ? nil : trimmed
        )
      )
      didSubmit = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

// MARK: - Moderation (admin)

struct BoardModerationSheet: View {
  let username: String
  @Environment(\.dismiss) private var dismiss
  @State private var kind: CommunitySanctionKind = .mute
  @State private var hours: Int? = 24
  @State private var reason = ""
  @State private var isSubmitting = false
  @State private var errorMessage: String?

  private let durations: [(label: LocalizedStringKey, hours: Int?)] = [
    ("1 day", 24), ("1 week", 168), ("30 days", 720), ("Indefinitely", nil)
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Action", selection: $kind) {
            Text("Mute").tag(CommunitySanctionKind.mute)
            Text("Ban").tag(CommunitySanctionKind.ban)
          }
          .pickerStyle(.segmented)
        } footer: {
          Text(kind == .mute
            ? "Can read, can't post, comment or vote."
            : "Loses access to Boards. The rest of Norviq still works.")
        }
        Section("For") {
          Picker("Duration", selection: $hours) {
            ForEach(durations.indices, id: \.self) { index in
              Text(durations[index].label).tag(durations[index].hours)
            }
          }
          .pickerStyle(.inline)
          .labelsHidden()
        }
        Section("Reason") {
          TextField("Spam in /dividends", text: $reason)
        }
        if let errorMessage {
          Section { Text(errorMessage).foregroundStyle(.red) }
        }
      }
      .navigationTitle(username)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Apply") { Task { await submit() } }
            .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
        }
      }
    }
  }

  private func submit() async {
    isSubmitting = true
    defer { isSubmitting = false }
    do {
      _ = try await Container.shared.boardsService().sanction(
        CreateSanctionRequest(username: username, kind: kind, reason: reason, durationHours: hours)
      )
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

// MARK: - Compose

struct ComposeBoardPostSheet: View {
  let board: BoardSummary
  let onPosted: (BoardPostSummary) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var kind: BoardPostKind = .link
  @State private var title = ""
  @State private var url = ""
  @State private var text = ""
  @State private var tags = ""
  @State private var isSubmitting = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Kind", selection: $kind) {
            Text("Link").tag(BoardPostKind.link)
            Text("Discussion").tag(BoardPostKind.text)
            Text("Ask").tag(BoardPostKind.ask)
            Text("Show").tag(BoardPostKind.show)
          }
          .pickerStyle(.segmented)
        }
        Section {
          TextField("Title", text: $title)
          if kind == .link {
            TextField("https://", text: $url)
              .keyboardType(.URL)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
          }
          TextField(kind == .link ? "Text (optional)" : "Text", text: $text, axis: .vertical).lineLimit(4...10)
        }
        Section {
          TextField("dividends, etf", text: $tags)
            .textInputAutocapitalization(.never)
        } header: {
          Text("Tags")
        } footer: {
          Text("Up to 5, comma separated.")
        }
        if let errorMessage {
          Section { Text(errorMessage).foregroundStyle(.red) }
        }
      }
      .navigationTitle("Post to \(board.name)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Post") { Task { await submit() } }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || isSubmitting)
        }
      }
    }
  }

  private func submit() async {
    isSubmitting = true
    defer { isSubmitting = false }
    let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let link = url.trimmingCharacters(in: .whitespacesAndNewlines)
    let request = CreateBoardPostRequest(
      kind: kind,
      title: title,
      url: kind == .link ? link : nil,
      body: body.isEmpty ? nil : body,
      tags: tags.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
    )
    do {
      let post = try await Container.shared.boardsService().createPost(slug: board.slug, request)
      onPosted(post)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

// MARK: - Create board

struct CreateBoardSheet: View {
  let model: BoardsDirectoryModel
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var slug = ""
  @State private var description = ""
  @State private var slugEdited = false
  @State private var isSubmitting = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
            .onChange(of: name) { _, value in
              if !slugEdited { slug = Self.suggestedSlug(from: value) }
            }
          TextField("Address", text: Binding(get: { slug }, set: { slug = $0; slugEdited = true }))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        } footer: {
          Text("norviq.org/boards/\(slug.isEmpty ? "…" : slug) — lowercase letters, numbers and dashes. Up to 3 boards a day.")
        }
        Section("What it's for") {
          TextField("Optional", text: $description, axis: .vertical).lineLimit(2...5)
        }
        if let message = model.errorMessage {
          Section { Text(message).foregroundStyle(.red) }
        }
      }
      .navigationTitle("New board")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") { Task { await submit() } }
            .disabled(name.count < 3 || slug.count < 3 || isSubmitting)
        }
      }
    }
  }

  private func submit() async {
    isSubmitting = true
    defer { isSubmitting = false }
    if await model.create(slug: slug, name: name, description: description) != nil {
      dismiss()
    }
  }

  /// "Dividend Investing!" → "dividend-investing".
  static func suggestedSlug(from name: String) -> String {
    let lowered = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
    let mapped = lowered.map { ($0.isASCII && ($0.isLetter || $0.isNumber)) ? $0 : "-" }
    let collapsed = String(mapped).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
    return String(collapsed.prefix(32))
  }
}

// MARK: - Guidelines

struct BoardsGuidelinesSheet: View {
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @Environment(\.dismiss) private var dismiss
  @State private var isAccepting = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text("Boards are for sharing ideas about money, markets and Norviq. By posting you agree to:")
          VStack(alignment: .leading, spacing: 8) {
            Label("No harassment, hate, threats or sexual content. Zero tolerance.", systemImage: "hand.raised")
            Label("No spam, scams, pump-and-dumps, referral farming or impersonation.", systemImage: "exclamationmark.shield")
            Label("Nothing here is financial advice. Say when you hold what you're talking about.", systemImage: "info.circle")
            Label("Don't post other people's personal or account information.", systemImage: "lock")
          }
          Text("Report anything that breaks these. Reported posts are reviewed within 24 hours, and people who break the rules are muted or removed.")
            .foregroundStyle(.secondary)
        }
        .padding()
      }
      .navigationTitle("Community guidelines")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("I agree") {
            Task {
              isAccepting = true
              await viewer.acceptGuidelines()
              isAccepting = false
              if !viewer.needsGuidelines { dismiss() }
            }
          }
          .disabled(isAccepting)
          .accessibilityIdentifier("boards.guidelines.accept")
        }
      }
    }
  }
}
