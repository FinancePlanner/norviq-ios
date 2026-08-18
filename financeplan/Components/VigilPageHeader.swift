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
    if BrandTheme.current == .vigil {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(watch.eyebrow)
            .vigilOverline()
            .foregroundStyle(AppTheme.Colors.tint(for: scheme).opacity(0.88))
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
    } else if subtitle != nil || hasTrailing {
      // Classic previously fell through to an implicit EmptyView, so 49 of the
      // 59 call sites silently lost their subtitle (and any trailing view)
      // whenever the user selected the Classic brand.
      //
      // The title is deliberately NOT rendered here. Under Classic
      // `vigilNavigationTitle` resolves to the real title, so every unguarded
      // call site already shows it in the navigation bar — including the two
      // screens that get it from a parent (PortfolioRoot, and
      // ChartBuilderStandaloneScreen for the embedded builder). Drawing it
      // again would double the title on all of them.
      //
      // The WATCH eyebrow is also omitted: "WATCH I — WEALTH" is Vigil
      // vocabulary from docs/vigil-identity.md and would leak that identity
      // into Classic, which predates it.
      HStack(alignment: .top, spacing: 12) {
        if let subtitle {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.secondaryText(for: scheme))
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        trailing
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
    }
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
