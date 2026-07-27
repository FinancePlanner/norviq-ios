import SwiftUI

/// Step-by-step guide for connecting an external AI agent (Claude, ChatGPT,
/// Cursor, Hermes, Claude Code) to the user's Norviq data over MCP.
struct MCPGuideView: View {
  @Environment(\.colorScheme) private var scheme

  private static let mcpEndpoint = "https://mcp.norviq.org/mcp"
  private static let tokenPageURL = URL(string: "https://norviq.org/settings/api-access")!

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("Let your AI assistant read expenses, quotes, reports, insights, and tax data — scoped to exactly what you allow, revocable any time.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Norviq provides the tools; your AI client provides (and bills) the model.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("Server address") {
        HStack {
          Text(Self.mcpEndpoint)
            .font(.footnote.monospaced())
            .textSelection(.enabled)
          Spacer()
          Button {
            UIPasteboard.general.string = Self.mcpEndpoint
          } label: {
            Image(systemName: "doc.on.doc")
          }
          .accessibilityLabel("Copy server address")
        }
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("What you can access") {
        stepText("Expenses, categories, recurring, CSV import/export")
        stepText("Spending reports, budgets, and goals")
        stepText("Quotes, symbol search, market insights")
        stepText("Tax dashboard and loss carryforwards")
        Text("Exact tools depend on the scopes on your personal access token (Pro).")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("1 · Claude (app & web)") {
        stepText("Settings → Connectors → Add custom connector.")
        stepText("Paste the server address and authorize in the browser with your Norviq login — no token needed for connector OAuth.")
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("2 · ChatGPT") {
        stepText("Settings → Connectors → Add. Paste the server address and complete the browser sign-in.")
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("3 · Cursor / Claude Code (token)") {
        stepText("Create a personal access token on the web app (button below), then add the server with the token as a bearer header:")
        codeBlock(
          "claude mcp add --transport http norviq \(Self.mcpEndpoint) --header \"Authorization: Bearer nvq_pat_…\""
        )
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("4 · Hermes Agent (token)") {
        stepText("Mint a token on the web app, then on the Hermes host (example profile mac-mcp):")
        codeBlock(
          """
          sudo hermes --profile mac-mcp mcp add norviq \\
            --url \(Self.mcpEndpoint) \\
            --auth header
          # Header: Authorization = Bearer nvq_pat_…
          sudo hermes --profile mac-mcp mcp test norviq
          """
        )
        stepText("Ask Hermes things like “list my recent expenses” or “quote AAPL.” Model cost stays with Hermes / your provider.")
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section {
        Link(destination: Self.tokenPageURL) {
          Label("Manage access tokens on the web", systemImage: "key.fill")
        }
      } footer: {
        Text("Tokens are Pro-only, scoped (expenses, reports, market, insights, tax), and revocable. Try it: ask your assistant to \u{201C}list my recent expenses\u{201D}.")
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }
    .scrollContentBackground(.hidden)
    .background(AppTheme.Colors.pageBackground(for: scheme))
    .navigationTitle("Connect an AI agent")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func stepText(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }

  private func codeBlock(_ text: String) -> some View {
    Text(text)
      .font(.caption.monospaced())
      .textSelection(.enabled)
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.Colors.pageBackground(for: scheme), in: .rect(cornerRadius: 8))
      .contextMenu {
        Button("Copy") {
          UIPasteboard.general.string = text
        }
      }
  }
}
