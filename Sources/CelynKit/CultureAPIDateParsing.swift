import Foundation
import os

/// Parse dates returned by culture-api. The API mixes three formats:
///   - ISO8601 with `Z` (`2026-04-25T18:30:00Z`)
///   - ISO8601 with fractional seconds (`2026-04-25T18:30:00.123Z`)
///   - PostgreSQL timestamps with offsets (`2026-04-25 18:30:00+00`)
public enum CultureAPIDateParsing {

    private static let logger = Logger(subsystem: "io.celyn.kit", category: "DateParsing")

    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated(unsafe) static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let postgres: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ssxx"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    public static func parse(_ string: String) -> Date? {
        if let date = iso8601.date(from: string)
            ?? iso8601Fractional.date(from: string)
            ?? postgres.date(from: string) {
            return date
        }
        logger.warning("Failed to parse date string: '\(string)'")
        return nil
    }
}
