import SwiftUI

/// Countries the backend serves macro data for — inflation, housing, growth and
/// policy. Kept in sync with `MacroCountryParam` in the OpenAPI spec, which in
/// turn covers every tax jurisdiction the app supports.
enum EconomyCountry: String, CaseIterable, Identifiable {
  case us = "US"
  case pt = "PT"
  case es = "ES"
  case de = "DE"
  case fr = "FR"
  case it = "IT"
  case br = "BR"
  case ea = "EA"

  var id: String { rawValue }

  var label: String {
    switch self {
    case .us: return String(localized: "US")
    case .pt: return String(localized: "Portugal")
    case .es: return String(localized: "Spain")
    case .de: return String(localized: "Germany")
    case .fr: return String(localized: "France")
    case .it: return String(localized: "Italy")
    case .br: return String(localized: "Brazil")
    case .ea: return String(localized: "Euro Area")
    }
  }

  var flag: String {
    switch self {
    case .us: return "🇺🇸"
    case .pt: return "🇵🇹"
    case .es: return "🇪🇸"
    case .de: return "🇩🇪"
    case .fr: return "🇫🇷"
    case .it: return "🇮🇹"
    case .br: return "🇧🇷"
    case .ea: return "🇪🇺"
    }
  }

  var pickerLabel: String { "\(flag) \(label)" }
}

struct EconomyCountryPicker: View {
  @Binding var selection: String

  var body: some View {
    // A menu rather than a segmented control: eight segments truncate to
    // unreadable stubs on an iPhone.
    Picker("Country", selection: $selection) {
      ForEach(EconomyCountry.allCases) { country in
        Text(country.pickerLabel).tag(country.rawValue)
      }
    }
    .pickerStyle(.menu)
    .accessibilityIdentifier("economy.countryPicker")
  }
}
