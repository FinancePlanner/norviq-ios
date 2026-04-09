import Factory
import SwiftUI
@preconcurrency import SwiftyCrop

// swiftlint:disable force_unwrapping
enum Constants {
  enum Norviqa {
    static let filesBaseUrl = URL(string: "https://files.norviqa.io")!

    static let appStoreUrl = URL(string: "https://apps.apple.com/us/app/norviqa/id6745227236")!

    static let webAppBaseUrl = URL(string: "https://www.norviqaapp.com")!

    static let swiftyCropConfiguration = SwiftyCropConfiguration(
      maxMagnificationScale: 4.0,
      maskRadius: 1_000,
      cropImageCircular: false,
      zoomSensitivity: 5.0
    )
  }
}

@Observable
final class AppEnvironmentManager {
  private(set) var current: AppEnvironment

  #if DEBUG
    let isDebugBuild = true
  #else
    let isDebugBuild = false
  #endif

  /// Environment forced by scheme (via env var or build-time pre-action)
  let schemeEnvironment: AppEnvironment?

  init() {
    let resolvedEnvironment: AppEnvironment

    // 1. Check runtime env var (set by Xcode LaunchAction)
    if let schemeEnvValue = ProcessInfo.processInfo.environment["NORVIQA_ENVIRONMENT"],
       let schemeEnv = AppEnvironments.from(key: schemeEnvValue) {
      schemeEnvironment = schemeEnv
      resolvedEnvironment = schemeEnv
    // 2. Check build-time generated value (set by scheme pre-action, works with sweetpad/CLI)
    } else if let buildEnvValue = SchemeEnvironment.value,
              let buildEnv = AppEnvironments.from(key: buildEnvValue) {
      schemeEnvironment = buildEnv
      resolvedEnvironment = buildEnv
    // 3. Check persisted user preference
    } else if
      let persistedEnvironment = UserDefaults.standard.string(forKey: "environment"),
      let environment = AppEnvironments.from(key: persistedEnvironment) {
      schemeEnvironment = nil
      resolvedEnvironment = environment
    // 4. Default based on build type
    } else {
      schemeEnvironment = nil
      resolvedEnvironment = isDebugBuild ? AppEnvironments.dev : AppEnvironments.production
    }

    self.current = resolvedEnvironment
  }

  func change(to newEnv: AppEnvironment) {
    guard newEnv != current else {
      return
    }
    current = newEnv
    Container.shared.reloadEnvironmentConfiguration(for: newEnv, onUpdate: {
      self.current = newEnv
      UserDefaults.standard.set(newEnv.title, forKey: "environment")
    })
  }

  @MainActor
  func allowedEnvironmentsWhen(isLoggedIn: Bool) -> [AppEnvironment] {
    if isDebugBuild {
      return AppEnvironments.allCases
    }

    if current == AppEnvironments.production {
      return isLoggedIn ? AppEnvironments.allEnvironmentsExcludingLocal : []
    }
    return AppEnvironments.allEnvironmentsExcludingLocal
  }
}

// swiftlint:enable force_unwrapping
