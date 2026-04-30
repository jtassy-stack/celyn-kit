import Foundation

public struct Seance: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let startsAt: Date
    public let endsAt: Date?
    public let language: String?
    public let format: String?
    public let priceMin: Double?
    public let priceMax: Double?
    public let bookingUrl: String?
    public let venue: VenueRef?
    public let oeuvre: OeuvreRef?
}

public struct SeanceListResponse: Codable, Sendable {
    public let data: [Seance]
    public let count: Int
}
