import Foundation
import Security

protocol SecureStringStoring {
  func string(for key: String) -> String?
  func setString(_ value: String, for key: String)
  func removeValue(for key: String)
}

final class KeychainStringStore: SecureStringStoring {
  private let service: String

  init(service: String) {
    self.service = service
  }

  func string(for key: String) -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess,
          let data = result as? Data,
          let value = String(data: data, encoding: .utf8) else {
      return nil
    }

    return value
  }

  func setString(_ value: String, for key: String) {
    let data = Data(value.utf8)
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key
    ]

    let attributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess {
      return
    }

    if updateStatus != errSecItemNotFound {
      SecItemDelete(query as CFDictionary)
    }

    var insert = query
    attributes.forEach { insert[$0.key] = $0.value }
    SecItemAdd(insert as CFDictionary, nil)
  }

  func removeValue(for key: String) {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key
    ]

    SecItemDelete(query as CFDictionary)
  }
}
