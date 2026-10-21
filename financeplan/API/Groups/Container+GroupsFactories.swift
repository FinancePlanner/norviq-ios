import Factory
import Foundation

extension Container {
  var groupsService: Factory<any GroupsServicing> {
    self { @MainActor in
      DefaultGroupsService(environmentManager: self.appEnvironment())
    }
  }

  /// One store for the Groups tab, its badge, the live connection and every
  /// chat screen, so a message read in one place clears the unread everywhere.
  var groupsStore: Factory<GroupsStore> {
    self { @MainActor in GroupsStore() }.singleton
  }
}
