import Kingfisher
import SwiftUI

// Returns an Icon, which is a resizable image with
public enum ImageType: Hashable, Equatable {
  case system(name: String)
  case named(_ name: String, renderingMode: Image.TemplateRenderingMode? = nil, bundle: Bundle? = nil)
  case web(_ url: URL?)

  // Returns a base Image for the given ImageType
  public var image: Image {
    let image = switch self {
    case let .system(name):
      Image(systemName: name).renderingMode(.template)
    case let .named(name, renderingMode, bundle):
      Image(name, bundle: bundle).renderingMode(renderingMode)
    default:
      Image("")
    }
    return image
  }

  @MainActor
  @ViewBuilder
  public func autoResizable() -> some View {
    switch self {
    case let .web(url):
      KFImage.url(url)
        .resizable()
    default:
      image.resizable()
    }
  }

  @MainActor
  public var icon: Icon {
    Icon(self)
  }

  public var iconImage: Image {
    image.resizable().renderingMode(.template)
  }

  @MainActor
  public func icon(withSize size: CGSize) -> Icon {
    Icon(self, size: size)
  }
}
