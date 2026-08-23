import SwiftUI

/// Settings hub for everything Norviq connects to: MCP clients, read-only
/// bank sync, receipt scanning, and API access. Informational by design —
/// deep-links to existing screens where they exist.
///
/// Vigil framing: "Speaks to your tools."
struct IntegrationsHubView: View {
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Image("CerberusHeadIcon")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
            .foregroundStyle(AppTheme.Colors.tint(for: scheme))
            .shadow(color: AppTheme.Colors.tint(for: scheme).opacity(0.45), radius: 10)
            .accessibilityHidden(true)
          Text("MCP ENGINE ROOM")
            .vigilOverline()
            .foregroundStyle(.secondary)
          Text("Speaks to your tools.")
            .font(.headline)
          Text("Norviq reads from your accounts and answers to your tools. It never places trades or moves funds.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("norviq:~$ status --protocol mcp")
            .font(.caption.monospaced())
            .foregroundStyle(AppTheme.Colors.tint(for: scheme))
            .padding(.top, 2)
          Text("Live token activity is managed on web API access. Live = used in the last 24h.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .listRowBackground(rowBackground)
      }

      Section {
        NavigationLink {
          MCPGuideView()
        } label: {
          VStack(alignment: .leading, spacing: 6) {
            Label("Connect an AI agent (MCP)", systemImage: "point.3.connected.trianglepath.dotted")
              .font(.body.weight(.semibold))
            Text("Connect Claude, ChatGPT, or Cursor to your Norviq data — expenses, market data, and insights, scoped to what you allow.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Text("Step-by-step setup with the server address and per-client instructions.")
              .font(.footnote)
              .foregroundStyle(.secondary)
            HStack(spacing: 8) {
              mcpScopeChip("Sentiment")
              mcpScopeChip("Portfolio")
              mcpScopeChip("Tax")
            }
            .padding(.top, 4)
          }
          .padding(.vertical, 4)
        }

        VStack(alignment: .leading, spacing: 6) {
          Label("API access", systemImage: "key.fill")
            .font(.body.weight(.semibold))
          Text("Personal access tokens grant scoped, revocable access. Manage them under Settings > API access on the web app.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      } header: {
        Text("Intelligence")
          .vigilOverline()
          .foregroundStyle(AppTheme.Colors.bronze(for: scheme))
      }
      .listRowBackground(rowBackground)

      Section {
        NavigationLink {
          IntegrationsView()
        } label: {
          VStack(alignment: .leading, spacing: 6) {
            Label("Brokerage & bank sync", systemImage: "building.columns")
              .font(.body.weight(.semibold))
            Text("Connect Interactive Brokers today. Bank sync via Plaid — read-only, always.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }

        VStack(alignment: .leading, spacing: 6) {
          Label("Receipt scanning", systemImage: "doc.viewfinder")
            .font(.body.weight(.semibold))
          Text("Scan a receipt from the quick expense sheet on Home. The ledger fills itself.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      } header: {
        Text("Wealth & Spending")
          .vigilOverline()
          .foregroundStyle(AppTheme.Colors.bronze(for: scheme))
      } footer: {
        Text("Every connection is read-only. The gate holds.")
      }
      .listRowBackground(rowBackground)
    }
    .vigilListChrome()
    .vigilScreenBackground()
    .vigilNavigationTitle("Integrations")
    .vigilInlineNavigationBar()
  }

  private var rowBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .fill(AppTheme.Colors.elevatedCardBackground(for: scheme))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(
            AppTheme.Colors.tint(for: scheme).opacity(BrandTheme.current == .vigil ? 0.22 : 0),
            lineWidth: 1
          )
      )
  }

  private func mcpScopeChip(_ title: String) -> some View {
    Text(title)
      .font(.caption2.weight(.bold).monospaced())
      .tracking(0.6)
      .textCase(.uppercase)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .foregroundStyle(
        BrandTheme.current == .vigil && scheme == .dark
          ? AppTheme.Colors.secondaryTint(for: scheme)
          : AppTheme.Colors.tint(for: scheme)
      )
      .background(
        Capsule()
          .fill(
            BrandTheme.current == .vigil && scheme == .dark
              ? AppTheme.Colors.secondaryTint(for: scheme).opacity(0.12)
              : AppTheme.Colors.tint(for: scheme).opacity(0.12)
          )
          .overlay(
            Capsule().stroke(
              BrandTheme.current == .vigil && scheme == .dark
                ? AppTheme.Colors.secondaryTint(for: scheme).opacity(0.45)
                : AppTheme.Colors.tint(for: scheme).opacity(0.35),
              lineWidth: 1
            )
          )
      )
  }
}

#Preview {
  NavigationStack {
    IntegrationsHubView()
  }
}
