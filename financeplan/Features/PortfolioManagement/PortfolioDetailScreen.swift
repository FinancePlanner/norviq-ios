import StockPlanShared
import SwiftUI

struct PortfolioDetailScreen: View {
  let portfolio: Portfolio
  let model: PortfolioWorkspaceViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var isInviting = false
  @State private var isAddingCash = false
  @State private var cloneName = ""
  @State private var isCloning = false

  var body: some View {
    List {
      Section("Details") {
        LabeledContent("Purpose", value: portfolio.purpose.rawValue.capitalized)
        LabeledContent("Ownership", value: portfolio.ownership.rawValue.capitalized)
        LabeledContent("Mode", value: portfolio.mode.rawValue.capitalized)
        LabeledContent("Role", value: portfolio.currentUserRole.rawValue.capitalized)
      }

      if portfolio.purpose == .retirement {
        Section {
          NavigationLink("Retirement plan") {
            RetirementPlanningScreen(portfolio: portfolio, service: model.service)
          }
        }
      }

      Section("Allocation") {
        NavigationLink {
          RebalancingScreen(portfolio: portfolio)
        } label: {
          Label("Targets & rebalancing", systemImage: "scope")
        }
      }

      Section("Cash") {
        ForEach(model.cashPositions) { cash in
          LabeledContent(cash.label, value: cash.balance.formatted(.currency(code: cash.currency)))
        }
        if portfolio.capabilities.canEdit {
          Button("Add cash position", systemImage: "plus") { isAddingCash = true }
        }
      }

      if portfolio.ownership == .joint {
        Section("People") {
          ForEach(model.members) { member in
            LabeledContent(member.displayName, value: member.role.rawValue.capitalized)
          }
          ForEach(model.invitations.filter { $0.status == .pending }) { invitation in
            LabeledContent(invitation.email, value: "Invited")
          }
          if portfolio.capabilities.canManageMembers {
            Button("Invite editor", systemImage: "person.badge.plus") { isInviting = true }
          }
        }
      }

      Section("What if") {
        Button("Clone as hypothetical", systemImage: "flask") {
          cloneName = "\(portfolio.name) — What if"
          isCloning = true
        }
      }

      if portfolio.capabilities.canArchive, !portfolio.isDefault {
        Section {
          Button("Archive portfolio", role: .destructive) {
            Task {
              if await model.archive(portfolio) {
                dismiss()
              }
            }
          }
        }
      }
    }
    .navigationTitle(portfolio.name)
    .task { await model.loadDetails(for: portfolio) }
    .refreshable { await model.loadDetails(for: portfolio) }
    .sheet(isPresented: $isInviting) { InvitePortfolioMemberSheet(portfolio: portfolio, model: model) }
    .sheet(isPresented: $isAddingCash) { AddCashPositionSheet(portfolio: portfolio, model: model) }
    .alert("Clone portfolio", isPresented: $isCloning) {
      TextField("Name", text: $cloneName)
      Button("Cancel", role: .cancel) {}
      Button("Clone") { Task { _ = await model.clone(portfolio, name: cloneName) } }
    } message: {
      Text("The clone is a fixed what-if sandbox and is excluded from net worth, tax, and account sync.")
    }
  }
}

private struct InvitePortfolioMemberSheet: View {
  @Environment(\.dismiss) private var dismiss
  let portfolio: Portfolio
  let model: PortfolioWorkspaceViewModel
  @State private var email = ""

  var body: some View {
    NavigationStack {
      Form {
        TextField("Email", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never)
        Text(
          "Only verified Norviq members can receive scheduled reports. A joint portfolio supports up to five editors."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }
      .navigationTitle("Invite editor")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Invite") {
            Task {
              if await model.invite(email: email, to: portfolio) {
                dismiss()
              }
            }
          }.disabled(!email.contains("@") || model.isSaving)
        }
      }
    }
  }
}

private struct AddCashPositionSheet: View {
  @Environment(\.dismiss) private var dismiss
  let portfolio: Portfolio
  let model: PortfolioWorkspaceViewModel
  @State private var label = "Cash"
  @State private var balance = 0.0

  var body: some View {
    NavigationStack {
      Form {
        TextField("Label", text: $label)
        TextField("Balance", value: $balance, format: .number).keyboardType(.decimalPad)
        LabeledContent("Currency", value: portfolio.baseCurrency)
      }
      .navigationTitle("Cash position")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            Task {
              if await model.addCash(label: label, balance: balance, currency: portfolio.baseCurrency, to: portfolio) {
                dismiss()
              }
            }
          }.disabled(label.isEmpty || model.isSaving)
        }
      }
    }
  }
}
