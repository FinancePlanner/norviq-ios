import SwiftUI

/// The native segmented chart-range control (DS 2.0). Segment titles are range
/// keys such as "1D" and are not translated; only the accessibility `label` is.
struct RangePicker: View {
    private let ranges: [ChartRange]
    @Binding private var selection: ChartRange
    private let label: LocalizedStringKey

    init(_ ranges: [ChartRange], selection: Binding<ChartRange>, label: LocalizedStringKey) {
        self.ranges = ranges
        _selection = selection
        self.label = label
    }

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(ranges) { range in
                Text(verbatim: range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(minHeight: 44)
        .accessibilityLabel(Text(label))
    }
}
