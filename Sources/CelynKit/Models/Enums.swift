import Foundation

public enum VenueType: String, Codable, Sendable, CaseIterable {
    case cinema
    case theatre
    case concertHall = "concert_hall"
    case museum
    case gallery
    case festival
    case bookshop
    case bar
    case restaurant
    case other

    /// Decodes unknown future values to `.other` rather than failing.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VenueType(rawValue: raw) ?? .other
    }
}

public enum OeuvreType: String, Codable, Sendable, CaseIterable {
    case film
    case tvshow
    case series
    case play
    case exhibition
    case concert
    case album
    case song
    case opera
    case dance
    case book
    case game
    case artwork
    case monument
    case festival
    case other

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = OeuvreType(rawValue: raw) ?? .other
    }
}

public enum Sentiment: String, Codable, Sendable, CaseIterable {
    case veryPositive = "very_positive"
    case positive
    case mixed
    case negative
    case veryNegative = "very_negative"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Sentiment(rawValue: raw) ?? .mixed
    }
}
