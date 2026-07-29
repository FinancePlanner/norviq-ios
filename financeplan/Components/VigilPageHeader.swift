import SwiftUI

/// Command Center page chrome mirroring web `modern-page-header`.
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
