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
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)
          Text("Speaks to your tools.")
            .font(.headline)
          Text("Norviq reads from your accounts and answers to your tools. It never places trades or moves funds.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
      }

      Section {
        VStack(alignment: .leading, spacing: 6) {
          Label("MCP integration", systemImage: "point.3.connected.trianglepath.dotted")
            .font(.body.weight(.semibold))
          Text("Connect Claude or any MCP client to your Norviq data — expenses, market data, and insights, scoped to what you allow.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("Generate a personal access token on the web app under Settings > API access, then add Norviq as an MCP server in your client.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 6) {
          Label("API access", systemImage: "key.fill")
            .font(.body.weight(.semibold))
          Text("Personal access tokens grant scoped, revocable access. Manage them under Settings > API access on the web app.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      } header: {
        Text("WATCH III — INTELLIGENCE")
          .font(.caption2.weight(.semibold))
          .tracking(1.2)
          .foregroundStyle(AppTheme.Colors.bronze(for: scheme))
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

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
        Text("WATCH I & II — WEALTH, SPENDING")
          .font(.caption2.weight(.semibold))
          .tracking(1.2)
          .foregroundStyle(AppTheme.Colors.bronze(for: scheme))
      } footer: {
        Text("Every connection is read-only. The gate holds.")
      }
      .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }
    .scrollContentBackground(.hidden)
    .listStyle(.insetGrouped)
    .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
    .navigationTitle("Integrations")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    IntegrationsHubView()
  }
}
