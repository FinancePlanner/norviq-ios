import Factory
import SwiftUI
@preconcurrency import SwiftyCrop

// swiftlint:disable force_unwrapping
enum Constants {
  enum Norviq {
    static let filesBaseUrl = URL(string: "https://files.norviqa.io")!

    static let shareBaseUrl = URL(string: "https://share.norviqa.io")!

    static let appStoreUrl = URL(string: "https://apps.apple.com/us/app/norviqa/id6745227236")!

    static let webAppBaseUrl = URL(string: "https://www.norviqaapp.com")!

    static let privacyPolicyUrl = URL(
      string: "https://gist.github.com/FACorreiaa/a60bcbf818a50a0e60df625f10021ef4"
    )!

    /// Apple's standard EULA (Terms of Use) used for auto-renewable subscriptions.
    static let termsOfUseUrl = URL(
      string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    static let swiftyCropConfiguration = SwiftyCropConfiguration(
      maxMagnificationScale: 4.0,
      maskRadius: 1_000,
      cropImageCircular: false,
      zoomSensitivity: 5.0
    )
  }
}

@Observable
final class AppEnvironmentManager: @unchecked Sendable {
  private(set) var current: AppEnvironment
  private let defaults: UserDefaults

  #if DEBUG
    private static let defaultIsDebugBuild = true
  #else
    private static let defaultIsDebugBuild = false
  #endif

  private static var defaultIsTestFlight: Bool {
    let receiptURL = Bundle.main.bundleURL.appendingPathComponent("StoreKit/sandboxReceipt")
    return FileManager.default.fileExists(atPath: receiptURL.path)
  }

  let isDebugBuild: Bool
  let isTestFlight: Bool

  /// Environment forced by scheme (via env var or build-time pre-action)
  let schemeEnvironment: AppEnvironment?

  init(
    environmentVariables: [String: String] = ProcessInfo.processInfo.environment,
    infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
    defaults: UserDefaults = .standard,
    schemeEnvironmentValue: String? = SchemeEnvironment.value,
    isDebugBuild: Bool = AppEnvironmentManager.defaultIsDebugBuild,
    isTestFlight: Bool = AppEnvironmentManager.defaultIsTestFlight
  ) {
    self.defaults = defaults
    self.isDebugBuild = isDebugBuild
    self.isTestFlight = isTestFlight
    let resolvedEnvironment: AppEnvironment
    let forcedEnvironment: AppEnvironment?

    // 1. Check runtime env var (set by Xcode LaunchAction)
    if let runtimeEnvironment = Self.environment(from: environmentVariables["NORVIQ_ENVIRONMENT"]) {
      forcedEnvironment = runtimeEnvironment
      resolvedEnvironment = runtimeEnvironment
    // 2. Check build-time Info.plist value (set by build configuration for archives/TestFlight)
    } else if let bundleEnvironment = Self.environment(
      from: infoDictionary?["NorviqAPIEnvironment"] as? String
    ) {
      forcedEnvironment = bundleEnvironment
      resolvedEnvironment = bundleEnvironment
    // 3. Check legacy generated value (kept for existing local scheme workflows)
    } else if let buildEnvironment = Self.environment(from: schemeEnvironmentValue) {
      forcedEnvironment = buildEnvironment
      resolvedEnvironment = buildEnvironment
    // 4. Check persisted user preference in debug builds only
    } else if
      isDebugBuild,
      let persistedEnvironment = defaults.string(forKey: "environment"),
      let environment = AppEnvironments.from(key: persistedEnvironment) {
      forcedEnvironment = nil
      resolvedEnvironment = environment
    // 5. Default based on build type
    } else if isDebugBuild {
      forcedEnvironment = nil
      resolvedEnvironment = AppEnvironments.local
    } else {
      forcedEnvironment = nil
      resolvedEnvironment = AppEnvironments.production
    }

    schemeEnvironment = forcedEnvironment
    self.current = resolvedEnvironment
  }

  func change(to newEnv: AppEnvironment) {
    guard newEnv != current else {
      return
    }
    current = newEnv
    Container.shared.reloadEnvironmentConfiguration(for: newEnv, onUpdate: {
      self.current = newEnv
      self.defaults.set(newEnv.title, forKey: "environment")
    })
  }

  @MainActor
  func allowedEnvironmentsWhen(isLoggedIn: Bool) -> [AppEnvironment] {
    if current == AppEnvironments.production {
      return []
    }
    return AppEnvironments.allCases
  }

  private static func environment(from value: String?) -> AppEnvironment? {
    guard let value else { return nil }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return nil }
    return AppEnvironments.from(key: normalized)
  }
}

// swiftlint:enable force_unwrapping
