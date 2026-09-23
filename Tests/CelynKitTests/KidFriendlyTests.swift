import XCTest
@testable import CelynKit

final class KidFriendlyTests: XCTestCase {
    private func oeuvre(_ type: String, kid: Bool? = nil, topics: [String] = ["Programme scolaire"], ageMax: Int? = nil) throws -> Oeuvre {
        var json: [String: Any] = ["id": "o1", "title": "T", "oeuvreType": type, "topics": topics]
        if let kid { json["isKidFriendly"] = kid }
        if let ageMax { json["ageMax"] = ageMax }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Oeuvre.self, from: data)
    }

    func testBookWithoutServerVerdictIsNeverKidFriendly() throws {
        XCTAssertFalse(try oeuvre("book").effectiveIsKidFriendly)
        XCTAssertFalse(try oeuvre("book", topics: ["famille"], ageMax: 10).effectiveIsKidFriendly)
    }

    func testFilmWithoutServerVerdictIsNeverKidFriendly() throws {
        XCTAssertFalse(try oeuvre("film", topics: ["famille"]).effectiveIsKidFriendly)
    }

    func testServerVerdictWins() throws {
        XCTAssertTrue(try oeuvre("book", kid: true).effectiveIsKidFriendly)
        XCTAssertFalse(try oeuvre("podcast", kid: false).effectiveIsKidFriendly)
    }

    func testHeuristicStillAppliesToOtherTypes() throws {
        XCTAssertTrue(try oeuvre("podcast", topics: ["famille"]).effectiveIsKidFriendly)
        XCTAssertFalse(try oeuvre("album").effectiveIsKidFriendly)
    }
}
