import SwiftUI

/// Step-by-step guide for connecting an external AI agent (Claude, ChatGPT,
/// Cursor, Claude Code) to the user's Norviq data over MCP.
struct MCPGuideView: View {
  @Environment(\.colorScheme) private var scheme

  private static let mcpEndpoint = "https://mcp.norviq.org/mcp"
  private static let tokenPageURL = URL(string: "https://norviq.org/settings/api-access")!

  var body: some View {
    List {
      Section {
        VigilPageHeader(
          watch: .intelligence,
          title: "Connect an AI agent",
          subtitle: "MCP server address and client recipes"
        )
        .listRowBackground(Color.clear)
      }

      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("Let your AI assistant read your expenses, quotes, reports, and insights — scoped to exactly what you allow, revocable any time.")
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

      Section("1 · Claude (app & web)") {
        stepText("Settings → Connectors → Add custom connector.")
        stepText("Paste the server address and authorize in the browser with your Norviq login — no token needed.")
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("2 · ChatGPT") {
        stepText("Settings → Connectors → Add. Paste the server address and complete the browser sign-in.")
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

      Section("3 · Cursor / Claude Code (token)") {
        stepText("Create a personal access token on the web app (button below), then add the server with the token as a bearer header:")
        Text("claude mcp add --transport http norviq \(Self.mcpEndpoint) --header \"Authorization: Bearer nvq_pat_…\"")
          .font(.caption.monospaced())
          .textSelection(.enabled)
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(AppTheme.Colors.pageBackground(for: scheme), in: .rect(cornerRadius: 8))
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
    .vigilListChrome()
    .vigilScreenBackground()
    .vigilNavigationTitle("Connect an AI agent")
    .vigilInlineNavigationBar()
  }

  private func stepText(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
}
