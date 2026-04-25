//
//  AppEnvironment.swift
//  financeplan
//
//  Created by Fernando Correia on 20.02.26.
//

import Foundation

// swiftlint:disable force_unwrapping
enum AppEnvironments {
  static let local = AppEnvironment(
    title: "local",
    apiBaseUrl: URL(string: "http://localhost:8080")!,
    wsBaseUrl: URL(string: "ws://localhost:8080/ws")!
  )
  static let dev = AppEnvironment(
    title: "dev",
    apiBaseUrl: URL(string: "https://www.dev-norviq.online")!,
    wsBaseUrl: URL(string: "wss://www.dev-norviq.online/ws")!
  )
  static let production = AppEnvironment(
    title: "production",
    apiBaseUrl: URL(string: "https://www.prod-norviq.online")!,
    wsBaseUrl: URL(string: "wss://www.prod-norviq.online/ws")!
  )

  static func from(key: String) -> AppEnvironment? {
    allCases.first(where: { $0.title == key })
  }

  static let allCases: [AppEnvironment] = [local, dev, production]

  static var allEnvironmentsExcludingLocal: [AppEnvironment] {
    allCases.filter { $0.title != "local" }
  }
}

struct AppEnvironment: Equatable, Hashable {
  let title: String
  let apiBaseUrl: URL
  let wsBaseUrl: URL
}
