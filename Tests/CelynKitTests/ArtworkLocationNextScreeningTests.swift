import XCTest
@testable import CelynKit

final class ArtworkLocationNextScreeningTests: XCTestCase {
    private func decode(_ json: String) throws -> Oeuvre {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)
            guard let date = CultureAPIDateParsing.parse(s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: s)
            }
            return date
        }
        return try decoder.decode(Oeuvre.self, from: Data(json.utf8))
    }

    private let base = #""id":"o1","title":"T","oeuvreType":"film""#

    func testAbsentKeysDecodeAsNil() throws {
        let o = try decode("{\(base)}")
        XCTAssertNil(o.nextScreeningAt)
        XCTAssertNil(o.nextScreening)
        XCTAssertNil(o.location)
    }

    func testExplicitNullsDecodeAsNil() throws {
        let o = try decode(#"{\#(base),"nextScreeningAt":null,"nextScreening":null,"location":null}"#)
        XCTAssertNil(o.nextScreeningAt)
        XCTAssertNil(o.nextScreening)
        XCTAssertNil(o.location)
    }

    func testFilmNextScreening() throws {
        let o = try decode(#"{\#(base),"nowShowing":true,"nextScreeningAt":"2026-09-25T18:30:00.000Z","nextScreening":{"startsAt":"2026-09-25T18:30:00Z","venueId":"v1","venueName":"Le Champo"}}"#)
        XCTAssertEqual(o.nextScreeningAt, ISO8601DateFormatter().date(from: "2026-09-25T18:30:00Z"))
        XCTAssertEqual(o.nextScreening?.venueId, "v1")
        XCTAssertEqual(o.nextScreening?.venueName, "Le Champo")
    }

    func testArtworkLocationMatchedAndUnmatched() throws {
        let matched = try decode(#"{"id":"a","title":"La Joconde","oeuvreType":"artwork","location":{"label":"Musée du Louvre","wikidataId":"Q19675","venueId":"v9","venue":{"id":"v9","name":"Louvre","city":"Paris","latitude":48.86,"longitude":2.33}}}"#)
        XCTAssertEqual(matched.location?.label, "Musée du Louvre")
        XCTAssertEqual(matched.location?.venue?.city, "Paris")
        XCTAssertEqual(matched.location?.venueId, "v9")

        let unmatched = try decode(#"{"id":"b","title":"X","oeuvreType":"artwork","location":{"label":"Rijksmuseum","wikidataId":null,"venueId":null,"venue":null}}"#)
        XCTAssertEqual(unmatched.location?.label, "Rijksmuseum")
        XCTAssertNil(unmatched.location?.venue)
        XCTAssertNil(unmatched.location?.venueId)
    }
}
