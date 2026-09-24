import Foundation
import os

/// Parse dates returned by culture-api. The API mixes three formats:
///   - ISO8601 with `Z` (`2026-04-25T18:30:00Z`)
///   - ISO8601 with fractional seconds (`2026-04-25T18:30:00.123Z`)
///   - PostgreSQL timestamps with offsets (`2026-04-25 18:30:00+00`),
///     optionally with 1–6 fractional digits (`2026-04-25 18:30:00.482497+00`)
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

    /// Raw-SQL aggregates over `timestamp without time zone` columns (e.g.
    /// `lastMentionedAt` on `sort=mentioned`) bypass Drizzle's Date mapping
    /// and arrive as bare `YYYY-MM-DD HH:mm:ss`. The DB stores UTC.
    static let postgresNaive: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// PostgreSQL DATE columns ship as bare `YYYY-MM-DD`. Kept as noon UTC
    /// (an invented time) on purpose: consumers only read the calendar day,
    /// and changing the anchor would shift existing apps' displays. Parsed at noon UTC
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

    /// Postgres text output for `timestamptz` with microseconds:
    /// `yyyy-MM-dd HH:mm:ss.f{1,6}` + `+00` / `+0000` / `+00:00` / `Z`.
    /// DateFormatter can't express "1 to 6 fraction digits", so the fraction is
    /// normalised to milliseconds and the result fed to the ISO formatter.
    static func parsePostgresFractional(_ string: String) -> Date? {
        let chars = Array(string.utf8)
        // "yyyy-MM-dd HH:mm:ss." is 20 bytes; separator is a space.
        guard chars.count > 20, chars[10] == UInt8(ascii: " "), chars[19] == UInt8(ascii: ".") else {
            return nil
        }
        var i = 20
        while i < chars.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(chars[i]) { i += 1 }
        let digits = i - 20
        guard (1...6).contains(digits) else { return nil }
        let fraction = String(decoding: chars[20..<i], as: UTF8.self)
        let millis = String((fraction + "00").prefix(3))
        let zone: String
        switch String(decoding: chars[i...], as: UTF8.self) {
        case "Z", "+00", "+0000", "+00:00": zone = "Z"
        default: return nil
        }
        let head = String(decoding: chars[0..<10], as: UTF8.self)
        let time = String(decoding: chars[11..<19], as: UTF8.self)
        return iso8601Fractional.date(from: "\(head)T\(time).\(millis)\(zone)")
    }

    public static func parse(_ string: String) -> Date? {
        parse(string, logger: logger)
    }

    /// Same as `parse(_:)`, logging failures to the given logger (the client's
    /// configured `logSubsystem`).
    static func parse(_ string: String, logger: Logger) -> Date? {
        // Fractional FIRST: the server is Drizzle `timestamp` serialised with
        // toISOString(), so it always emits `.000Z`. The non-fractional
        // formatter therefore missed on ~100% of real payloads while still
        // paying full parse cost — on the order of 6 date fields × 560 events
        // per cold agenda load. The two formatters accept disjoint inputs
        // (`.withFractionalSeconds` requires the fraction), so the order
        // cannot change which Date comes back.
        if let date = iso8601Fractional.date(from: string)
            ?? iso8601.date(from: string)
            ?? postgres.date(from: string)
            ?? postgresNaive.date(from: string)
            ?? parsePostgresFractional(string) {
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
