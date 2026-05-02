import Combine
import SwiftUI

@MainActor
class Debouncer<T>: ObservableObject {
  @Published var value: T
  @Published private(set) var debouncedValue: T

  private var cancellable: AnyCancellable?

  init(
    value: T,
    for dueTime: DispatchQueue.SchedulerTimeType.Stride,
    scheduler: DispatchQueue
  ) {
    self.value = value
    debouncedValue = value

    cancellable = $value
      .debounce(for: dueTime, scheduler: scheduler)
      .sink { [weak self] in
        self?.debouncedValue = $0
      }
  }

  func update(_ value: T) {
    self.value = value
  }
}
