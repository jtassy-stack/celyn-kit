import XCTest
@testable import CelynKit

final class EventsListParamsTests: XCTestCase {
    func testOeuvreIdIsSentAsSnakeCaseWithoutLocation() {
        let q = EventsResource.ListParams(limit: 100, oeuvreId: "abc-123").queryItems
        XCTAssertEqual(q, ["oeuvre_id": "abc-123", "limit": "100"])
    }

    func testOeuvreIdCombinesWithLocation() {
        let q = EventsResource.ListParams(lat: 48.85, lng: 2.35, radiusKm: 25, oeuvreId: "abc").queryItems
        XCTAssertEqual(q["oeuvre_id"], "abc")
        XCTAssertEqual(q["lat"], "48.85")
        XCTAssertEqual(q["radius_km"], "25.0")
    }

    func testAbsentOrEmptyOeuvreIdIsOmitted() {
        XCTAssertNil(EventsResource.ListParams().queryItems["oeuvre_id"])
        XCTAssertNil(EventsResource.ListParams(oeuvreId: "").queryItems["oeuvre_id"])
    }

    func testExistingParamsUnchanged() {
        let q = EventsResource.ListParams(happeningNow: true, category: "concert").queryItems
        XCTAssertEqual(q, ["happening_now": "true", "category": "concert"])
    }
}
