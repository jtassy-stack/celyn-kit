import XCTest
@testable import CelynKit

final class CelynKitTests: XCTestCase {

    func testClientIsConfiguredWithKey() {
        let client = CultureAPIClient(apiKey: "test-key")
        XCTAssertTrue(client.isConfigured)
    }

    func testClientIsNotConfiguredWithEmptyKey() {
        let client = CultureAPIClient(apiKey: "")
        XCTAssertFalse(client.isConfigured)
    }

    func testDateParsingISO8601() {
        let date = CultureAPIDateParsing.parse("2026-04-25T18:30:00Z")
        XCTAssertNotNil(date)
    }

    func testDateParsingISO8601Fractional() {
        let date = CultureAPIDateParsing.parse("2026-04-25T18:30:00.123Z")
        XCTAssertNotNil(date)
    }

    func testDateParsingPostgres() {
        let date = CultureAPIDateParsing.parse("2026-04-25 18:30:00+00")
        XCTAssertNotNil(date)
    }

    func testDateParsingInvalid() {
        let date = CultureAPIDateParsing.parse("not a date")
        XCTAssertNil(date)
    }

    func testVenueTypeUnknownDecodesToOther() throws {
        let json = #""some_future_type""#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VenueType.self, from: json)
        XCTAssertEqual(decoded, .other)
    }

    func testVenueDecodingFromAPIShape() throws {
        let json = """
        {
            "id": "v1",
            "name": "Le Grand Action",
            "address": "5 rue des Écoles",
            "city": "Paris",
            "latitude": 48.8492,
            "longitude": 2.3494,
            "venue_type": "cinema",
            "website": null,
            "geofence_radius": null,
            "mention_count": 12
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let venue = try decoder.decode(Venue.self, from: json)

        XCTAssertEqual(venue.id, "v1")
        XCTAssertEqual(venue.name, "Le Grand Action")
        XCTAssertEqual(venue.venueType, .cinema)
        XCTAssertEqual(venue.mentionCount, 12)
        XCTAssertEqual(venue.latitude, 48.8492)
    }

    func testEventListResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "e1",
                    "title": "Anatomie d'une chute",
                    "category": "cinema",
                    "image_url": null,
                    "start_time": "2026-04-25T20:00:00Z",
                    "end_time": null,
                    "price": null,
                    "is_free": 0,
                    "is_sold_out": 0,
                    "is_active": 1,
                    "venue": null,
                    "oeuvre": null
                }
            ],
            "count": 1
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            guard let d = CultureAPIDateParsing.parse(str) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "")
            }
            return d
        }

        let response = try decoder.decode(EventListResponse.self, from: json)
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.data.first?.title, "Anatomie d'une chute")
        XCTAssertFalse(response.data.first?.isFreeBool ?? true)
        XCTAssertTrue(response.data.first?.isActiveBool ?? false)
    }
}
