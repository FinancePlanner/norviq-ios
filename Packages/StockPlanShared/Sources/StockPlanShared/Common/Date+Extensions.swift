import Foundation

public extension DateFormatter {
    static let iso8601WithFractionalSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()

    static let iso8601Standard: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()

    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

public enum SharedDateDecoder {
    /// Formatters are expensive to build and safe to share for parsing, so
    /// they're created once per process instead of once per Date field.
    /// ISO8601DateFormatter is documented thread-safe but isn't annotated
    /// Sendable in the SDK, hence `nonisolated(unsafe)`. Never mutate these
    /// after construction.
    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = .init()

    nonisolated(unsafe) static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseDateString(_ stringValue: String) -> Date? {
        if let parsed = iso8601.date(from: stringValue) {
            return parsed
        }
        if let parsed = iso8601Fractional.date(from: stringValue) {
            return parsed
        }
        if let parsed = DateFormatter.yyyyMMdd.date(from: stringValue) {
            return parsed
        }
        return nil
    }

    public static func decodeDate<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> Date {
        if let stringValue = try? container.decode(String.self, forKey: key) {
            if let parsed = parseDateString(stringValue) {
                return parsed
            }

            if let referenceSeconds = Double(stringValue) {
                return Date(timeIntervalSinceReferenceDate: referenceSeconds)
            }
        }

        if let referenceSeconds = try? container.decode(Double.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: referenceSeconds)
        }

        if let referenceSeconds = try? container.decode(Int.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: Double(referenceSeconds))
        }

        throw DecodingError.typeMismatch(
            Date.self,
            .init(
                codingPath: container.codingPath + [key],
                debugDescription: "Date must be an ISO8601 string or seconds since Apple reference date"
            )
        )
    }

    public static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            if let parsed = parseDateString(stringValue) {
                return parsed
            }

            if let referenceSeconds = Double(stringValue) {
                return Date(timeIntervalSinceReferenceDate: referenceSeconds)
            }
        }

        if let referenceSeconds = try? container.decode(Double.self) {
            return Date(timeIntervalSinceReferenceDate: referenceSeconds)
        }

        if let referenceSeconds = try? container.decode(Int.self) {
            return Date(timeIntervalSinceReferenceDate: Double(referenceSeconds))
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Date must be an ISO8601 string or seconds since Apple reference date"
        )
    }
}

public extension JSONDecoder {
    /// Shared, process-wide decoder configured for the StockPlan API.
    ///
    /// This is a single cached instance: do **not** mutate it. Callers that
    /// need a differently-configured decoder must start from
    /// ``makeStockPlanShared()`` instead.
    static let stockPlanShared: JSONDecoder = makeStockPlanShared()

    /// Builds a fresh decoder with the StockPlan configuration. Use this when
    /// you intend to customise strategies on the returned instance.
    static func makeStockPlanShared() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            try SharedDateDecoder.decodeDate(from: decoder)
        }
        return decoder
    }
}

public extension JSONEncoder {
    /// Shared, process-wide encoder configured for the StockPlan API.
    /// Single cached instance: do **not** mutate it; use
    /// ``makeStockPlanShared()`` for a customisable copy.
    static let stockPlanShared: JSONEncoder = makeStockPlanShared()

    /// Builds a fresh encoder with the StockPlan configuration.
    static func makeStockPlanShared() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
