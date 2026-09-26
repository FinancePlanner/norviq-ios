import SwiftUI

/// A friend's photo, or their initial on a tinted circle.
struct SocialAvatar: View {
  let user: SocialUserSummary
  var size: CGFloat = 40

  var body: some View {
    Group {
      if let url = user.avatarUrl.flatMap(URL.init(string:)) {
        AsyncImage(url: url) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          initial
        }
      } else {
        initial
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .accessibilityHidden(true)
  }

  private var initial: some View {
    ZStack {
      Circle().fill(AppTheme.Colors.tint.opacity(0.18))
      Text(String(user.title.drop(while: { $0 == "@" }).prefix(1)).uppercased())
        .font(.system(size: size * 0.42, weight: .semibold))
        .foregroundStyle(AppTheme.Colors.tint)
    }
  }
}

/// One person in a list: avatar, name and handle, with room for a trailing action.
struct SocialUserRow<Trailing: View>: View {
  let user: SocialUserSummary
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(spacing: 12) {
      SocialAvatar(user: user)
      VStack(alignment: .leading, spacing: 2) {
        Text(user.title)
          .typography(.label, weight: .semibold)
          .lineLimit(1)
        Text("@\(user.username)")
          .typography(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      trailing()
    }
    .accessibilityElement(children: .combine)
  }
}

extension SocialUserRow where Trailing == EmptyView {
  init(user: SocialUserSummary) {
    self.init(user: user, trailing: { EmptyView() })
  }
}
