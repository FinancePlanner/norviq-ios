import Foundation
import Security

enum SecureStoreError: LocalizedError, Equatable {
  case readFailed(OSStatus)
  case writeFailed(OSStatus)
  case deleteFailed(OSStatus)
  case invalidEncoding

  var errorDescription: String? {
    switch self {
    case let .readFailed(status):
      return "Secure store read failed (\(status))."
    case let .writeFailed(status):
      return "Secure store write failed (\(status))."
    case let .deleteFailed(status):
      return "Secure store delete failed (\(status))."
    case .invalidEncoding:
      return "Secure store value has invalid encoding."
    }
  }
}

protocol SecureStringStoring: Sendable {
  nonisolated func string(for key: String) throws -> String?
  nonisolated func setString(_ value: String, for key: String) throws
  nonisolated func removeValue(for key: String) throws
}

final class KeychainStringStore: SecureStringStoring, Sendable {
  private let service: String

  init(service: String) {
    self.service = service
  }

  nonisolated func string(for key: String) throws -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecAttrSynchronizable: kCFBooleanFalse as Any,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status != errSecItemNotFound else {
      return nil
    }
    guard status == errSecSuccess else {
      throw SecureStoreError.readFailed(status)
    }
    guard let data = result as? Data,
          let value = String(data: data, encoding: .utf8)
    else {
      throw SecureStoreError.invalidEncoding
    }
    return value
  }

  nonisolated func setString(_ value: String, for key: String) throws {
    let data = Data(value.utf8)
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecAttrSynchronizable: kCFBooleanFalse as Any
    ]

    let attributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess {
      return
    }

    guard updateStatus == errSecItemNotFound else {
      throw SecureStoreError.writeFailed(updateStatus)
    }

    var insert = query
    attributes.forEach { insert[$0.key] = $0.value }
    let addStatus = SecItemAdd(insert as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw SecureStoreError.writeFailed(addStatus)
    }
  }

  nonisolated func removeValue(for key: String) throws {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
      kSecAttrSynchronizable: kCFBooleanFalse as Any
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw SecureStoreError.deleteFailed(status)
    }
  }
}
