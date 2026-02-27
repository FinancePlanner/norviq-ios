import SwiftUI

enum SelectedMedia {
  case image(Data)
  case video(URL, thumbnail: Data?)
}
