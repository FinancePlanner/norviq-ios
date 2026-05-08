//
//  SecurityCodeView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI

struct SecurityCodeView: View {
    let manager: SecurityCodeManaging
    @Binding var isEnabled: Bool
    @Environment(\.colorScheme) private var scheme

    @State private var setupCode = ""
    @State private var setupConfirmation = ""
    @State private var currentCode = ""
    @State private var replacementCode = ""
    @State private var replacementConfirmation = ""
    @State private var removalCode = ""
    @State private var message: String?
    @State private var isErrorMessage = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    let title: LocalizedStringKey =
                        isEnabled ? "Security Code is enabled" : "Security Code is off"
                    Label(title, systemImage: isEnabled ? "lock.shield.fill" : "lock.open.fill")
                        .typography(.label, weight: .semibold)

                    Text(
                        "Use a 6-digit code to unlock Norviq when Face ID or device passcode is unavailable."
                    )
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            if isEnabled {
                changeSection
                removeSection
            } else {
                setupSection
            }

            if let message {
                Section {
                    Text(message)
                        .typography(.caption)
                        .foregroundStyle(
                            isErrorMessage ? AppTheme.Colors.danger : AppTheme.Colors.success)
                }
                .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Security Code")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isEnabled = manager.isEnabled
        }
    }

    private var setupSection: some View {
        Section {
            codeField("New 6-digit code", text: $setupCode)
            codeField("Confirm code", text: $setupConfirmation)

            Button {
                setCode()
            } label: {
                Label("Turn On Security Code", systemImage: "lock.fill")
            }
            .disabled(setupCode.count != 6 || setupConfirmation.count != 6)
        } header: {
            Text("Set Up")
        }
        .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }

    private var changeSection: some View {
        Section {
            codeField("Current code", text: $currentCode)
            codeField("New 6-digit code", text: $replacementCode)
            codeField("Confirm new code", text: $replacementConfirmation)

            Button {
                changeCode()
            } label: {
                Label("Change Security Code", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(
                currentCode.count != 6 || replacementCode.count != 6
                    || replacementConfirmation.count != 6)
        } header: {
            Text("Change")
        }
        .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }

    private var removeSection: some View {
        Section {
            codeField("Current code", text: $removalCode)

            Button(role: .destructive) {
                removeCode()
            } label: {
                Label("Turn Off Security Code", systemImage: "lock.slash")
            }
            .disabled(removalCode.count != 6)
        } header: {
            Text("Remove")
        }
        .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }

    private func codeField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.body.monospacedDigit())
            .onChange(of: text.wrappedValue) { _, newValue in
                text.wrappedValue = String(newValue.filter(\.isNumber).prefix(6))
            }
    }

    private func setCode() {
        guard setupCode == setupConfirmation else {
            show("Security Code confirmation does not match.", isError: true)
            return
        }

        do {
            try manager.setCode(setupCode)
            setupCode = ""
            setupConfirmation = ""
            isEnabled = true
            show("Security Code is enabled.", isError: false)
        } catch {
            show(errorMessage(for: error), isError: true)
        }
    }

    private func changeCode() {
        guard replacementCode == replacementConfirmation else {
            show("New Security Code confirmation does not match.", isError: true)
            return
        }

        do {
            try manager.changeCode(currentCode: currentCode, newCode: replacementCode)
            currentCode = ""
            replacementCode = ""
            replacementConfirmation = ""
            isEnabled = true
            show("Security Code was changed.", isError: false)
        } catch {
            show(errorMessage(for: error), isError: true)
        }
    }

    private func removeCode() {
        do {
            try manager.removeCode(currentCode: removalCode)
            removalCode = ""
            isEnabled = false
            show("Security Code is off.", isError: false)
        } catch {
            show(errorMessage(for: error), isError: true)
        }
    }

    private func show(_ value: String, isError: Bool) {
        message = value
        isErrorMessage = isError
    }

    private func errorMessage(for error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Unable to update Security Code."
    }
}
