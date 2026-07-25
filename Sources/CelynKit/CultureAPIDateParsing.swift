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

    /// PostgreSQL DATE columns ship as bare `YYYY-MM-DD`. Parsed at noon UTC
    /// (rather than midnight) so re-rendering in any local timezone still
    /// resolves to the intended calendar day — a midnight UTC anchor would
    /// flip back one day under Europe/Paris (UTC+1/+2).
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    public static func parse(_ string: String) -> Date? {
        // Fractional FIRST: the server is Drizzle `timestamp` serialised with
        // toISOString(), so it always emits `.000Z`. The non-fractional
        // formatter therefore missed on ~100% of real payloads while still
        // paying full parse cost — on the order of 6 date fields × 560 events
        // per cold agenda load. The two formatters accept disjoint inputs
        // (`.withFractionalSeconds` requires the fraction), so the order
        // cannot change which Date comes back.
        if let date = iso8601Fractional.date(from: string)
            ?? iso8601.date(from: string)
            ?? postgres.date(from: string) {
            return date
        }
        if let dateMidnight = dateOnly.date(from: string) {
            // Anchor at noon UTC for timezone-safe display.
            return dateMidnight.addingTimeInterval(12 * 3600)
        }
        logger.warning("Failed to parse date string: '\(string)'")
        return nil
    }
}
