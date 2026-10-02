import Factory
import Foundation

extension Container {
  var boardsService: Factory<any BoardsServicing> {
    self { @MainActor in
      DefaultBoardsService(environmentManager: self.appEnvironment())
    }
  }

  /// Who the viewer is on Boards (admin, muted, banned, set up). Shared so a
  /// guidelines acceptance or a mute shows up on every Boards screen at once.
  var boardsViewerStore: Factory<BoardsViewerStore> {
    self { @MainActor in BoardsViewerStore() }.singleton
  }
}
