import Foundation

/// User-suggested events attached to a venue the app already knows, pending
/// editorial review.
///
/// Surfaced from the Carte venue sheet's empty-events state: the venue is
/// known, only the event is missing — so `venueId` + `venueName` + coords are
/// carried on the submission and the user supplies the rest. Anonymous —
/// `deviceIdHash` rate-limits (5/day/device) and is never linked to identity.
/// See `culture-api`'s `POST /events/submissions`.
public struct EventSubmissionsResource: Sendable {
    let client: CultureAPIClient

    /// Categories the picker offers. Mirrors the app's `Rubrique` taxonomy
    /// (and `events.category` server-side, which is free-form). The moderator
    /// keeps or maps it to the canonical category when promoting.
    public enum Category: String, Sendable, CaseIterable, Codable {
        case concert
        case theatre
        case opera
        case danse
        case cinema
        case expos
        case livres
        case festivals
        case restos
        case other

        public var frenchLabel: String {
            switch self {
            case .concert:   return "Concert"
            case .theatre:   return "Théâtre"
            case .opera:     return "Opéra"
            case .danse:     return "Danse"
            case .cinema:    return "Cinéma"
            case .expos:     return "Exposition"
            case .livres:    return "Livre / rencontre"
            case .festivals: return "Festival"
            case .restos:    return "Table"
            case .other:     return "Autre"
            }
        }
    }

    public struct Submission: Sendable, Encodable {
        public var title: String
        public var category: Category
        /// The known venue's id, when the app has it (a `.other` event-only
        /// pin absent from `/venues` submits with nil — `venueName` + coords
        /// still locate it for the editor).
        public var venueId: String?
        public var venueName: String
        public var lat: Double
        public var lng: Double
        public var description: String?
        public var sourceUrl: String?
        /// ISO-8601 strings, not `Date`: the client's JSONEncoder only sets
        /// `.convertToSnakeCase` (no date strategy), and the server validates
        /// `start_time` as an ISO-8601 string. `startTime` required (an
        /// undated event can't be promoted), `endTime` optional.
        public var startTime: String
        public var endTime: String?
        /// 64 hex chars (SHA-256), from `DeviceIdProvider.hash`.
        public var deviceIdHash: String

        public init(
            title: String,
            category: Category,
            venueId: String?,
            venueName: String,
            lat: Double,
            lng: Double,
            description: String? = nil,
            sourceUrl: String? = nil,
            startTime: String,
            endTime: String? = nil,
            deviceIdHash: String
        ) {
            self.title = title
            self.category = category
            self.venueId = venueId
            self.venueName = venueName
            self.lat = lat
            self.lng = lng
            self.description = description
            self.sourceUrl = sourceUrl
            self.startTime = startTime
            self.endTime = endTime
            self.deviceIdHash = deviceIdHash
        }
    }

    public struct Receipt: Sendable, Decodable {
        public let id: String
        public let status: String
    }

    /// Posts an event suggestion. On success returns the server-assigned id
    /// and the row's initial status (`"pending"`). On rate-limit the client
    /// receives a 429 — surfaced as `CultureAPIError.httpError` with
    /// statusCode 429 so callers can render a French "Réessayez plus tard"
    /// hint without parsing the body shape.
    public func submit(_ submission: Submission) async throws -> Receipt {
        try await client.post("events/submissions", body: submission)
    }
}
