import SwiftUI

/// Page chrome that renders the domain eyebrow and screen title.
/// The subtitle is optional — only use it when it carries genuinely
/// new information (e.g. a dynamic value like a period or asset name).
/// Static descriptions that restate the title should be omitted.
struct VigilPageHeader<Trailing: View>: View {
  @Environment(\.colorScheme) private var scheme

  let watch: VigilWatch
  let title: Text
  let subtitle: Text?
  /// `.displayTitle` (Brygada 1918) for a page title. A title that is a symbol,
  /// such as a ticker, passes `.title` so it stays SF like every other figure.
  let titleStyle: Typography
  let trailing: Trailing

  init(
    watch: VigilWatch,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey? = nil,
    titleStyle: Typography = .displayTitle,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) {
    self.watch = watch
    self.title = Text(title)
    self.titleStyle = titleStyle
    self.subtitle = subtitle.map { Text($0) }
    self.trailing = trailing()
  }

  /// For titles that come from data, such as a fund's name: shown exactly as
  /// given, with no catalog lookup and no Markdown, so a `*` or `_` in a name
  /// stays a character.
  init(
    watch: VigilWatch,
    verbatimTitle: String,
    verbatimSubtitle: String? = nil,
    titleStyle: Typography = .displayTitle,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) {
    self.watch = watch
    title = Text(verbatim: verbatimTitle)
    self.titleStyle = titleStyle
    subtitle = verbatimSubtitle.map { Text(verbatim: $0) }
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
        title
          // Brygada 1918 by default, the display face (DS 2.0 § 9.0 Q2) for page
          // titles; tickers pass `.title`. Wraps rather than truncates (fixedSize below).
          .typography(titleStyle)
          .foregroundStyle(AppTheme.Colors.foreground(for: scheme))
          .fixedSize(horizontal: false, vertical: true)
        if let subtitle {
          subtitle
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
  init(
    watch: VigilWatch,
    title: LocalizedStringKey,
    subtitle: LocalizedStringKey? = nil,
    titleStyle: Typography = .displayTitle
  ) {
    self.init(watch: watch, title: title, subtitle: subtitle, titleStyle: titleStyle, trailing: { EmptyView() })
  }

  init(
    watch: VigilWatch,
    verbatimTitle: String,
    verbatimSubtitle: String? = nil,
    titleStyle: Typography = .displayTitle
  ) {
    self.init(
      watch: watch,
      verbatimTitle: verbatimTitle,
      verbatimSubtitle: verbatimSubtitle,
      titleStyle: titleStyle,
      trailing: { EmptyView() }
    )
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
