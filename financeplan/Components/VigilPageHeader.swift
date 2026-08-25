import SwiftUI

/// Page chrome that renders the domain eyebrow and screen title.
/// The subtitle is optional — only use it when it carries genuinely
/// new information (e.g. a dynamic value like a period or asset name).
/// Static descriptions that restate the title should be omitted.
struct VigilPageHeader<Trailing: View>: View {
  @Environment(\.colorScheme) private var scheme

  let watch: VigilWatch
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey?
  let trailing: Trailing

  init(
    watch: VigilWatch,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey? = nil,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) {
    self.watch = watch
    self.title = title
    self.subtitle = subtitle
    self.trailing = trailing()
  }

  /// True when the caller supplied no trailing view, so the Classic branch can
  /// collapse to nothing rather than leaving an empty row inside a `List`.
  private var hasTrailing: Bool { Trailing.self != EmptyView.self }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        Text(watch.eyebrow)
          .vigilOverline()
          // Not the accent tint: this eyebrow renders on 60 screens, and
          // colouring all of them made the WATCH label compete with the title
          // it introduces. It is a label, so it reads as one.
          .foregroundStyle(.secondary)
        Text(title)
          .font(.title2.bold())
          .foregroundStyle(AppTheme.Colors.foreground(for: scheme))
          .fixedSize(horizontal: false, vertical: true)
        if let subtitle {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.secondaryText(for: scheme))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 8)
      trailing
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

extension VigilPageHeader where Trailing == EmptyView {
  init(watch: VigilWatch, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
    self.init(watch: watch, title: title, subtitle: subtitle, trailing: { EmptyView() })
  }
}

#Preview {
  VStack(alignment: .leading) {
    VigilPageHeader(
      watch: .wealth,
      title: "Holdings",
      subtitle: "Your stock, ETF, and crypto positions"
    )
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
