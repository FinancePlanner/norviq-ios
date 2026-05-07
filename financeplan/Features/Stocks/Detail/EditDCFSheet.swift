import SwiftUI

struct EditDCFSheet: View {
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage("userWACC") private var userWACC: Double = 0.09
    @AppStorage("userTerminalGrowthRate") private var userTerminalGrowthRate: Double = 0.025
    @AppStorage("userTerminalMargin") private var userTerminalMargin: Double = 0.22
    @AppStorage("userFCFMarginAssumption") private var userFCFMarginAssumption: Double = 1.10

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Discount Rate")) {
                    VStack(alignment: .leading) {
                        Text("WACC (Weighted Average Cost of Capital)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userWACC, in: 0.05...0.20, step: 0.005)
                            Text(userWACC, format: .percent.precision(.fractionLength(1)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                Section(header: Text("Terminal Value Assumptions")) {
                    VStack(alignment: .leading) {
                        Text("Terminal Growth Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userTerminalGrowthRate, in: 0.01...0.05, step: 0.005)
                            Text(userTerminalGrowthRate, format: .percent.precision(.fractionLength(1)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Terminal Margin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userTerminalMargin, in: 0.05...0.50, step: 0.01)
                            Text(userTerminalMargin, format: .percent.precision(.fractionLength(0)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                Section(header: Text("Cash Flow Assumptions")) {
                    VStack(alignment: .leading) {
                        Text("FCF to Net Income Ratio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userFCFMarginAssumption, in: 0.5...2.0, step: 0.05)
                            Text(userFCFMarginAssumption, format: .number.precision(.fractionLength(2)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                Section {
                    Button(action: {
                        userWACC = 0.09
                        userTerminalGrowthRate = 0.025
                        userTerminalMargin = 0.22
                        userFCFMarginAssumption = 1.10
                    }) {
                        Text("Reset to Defaults")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit DCF Parameters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
