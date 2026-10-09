import XCTest
@testable import CelynKit

final class MeRequestsTests: XCTestCase {
    func testRequestsDecodeLikeTheCircle() throws {
        let json = #"{"data":[{"id":"u1","displayName":"Alice","since":"2026-10-09T07:00:00.000Z"},{"id":"u2","displayName":null,"since":"2026-10-08T07:00:00.000Z"}],"count":2}"#
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            return CultureAPIDateParsing.parse(s) ?? Date()
        }
        let r = try d.decode(CircleListResponse<CircleMember>.self, from: Data(json.utf8))
        XCTAssertEqual(r.data.map(\.id), ["u1", "u2"])
        XCTAssertNil(r.data[1].displayName)
        XCTAssertNil(r.data[0].phone)
    }

    func testDismissResponseDecodes() throws {
        XCTAssertTrue(try JSONDecoder().decode(DismissResponse.self, from: Data(#"{"dismissed":true}"#.utf8)).dismissed)
    }
}
