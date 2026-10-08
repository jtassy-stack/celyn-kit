import XCTest
@testable import CelynKit

final class MeSafetyTests: XCTestCase {
    func testReportReasonsMatchTheServerConstraint() throws {
        // culture-api migration 0174: user_reports_reason_check.
        XCTAssertEqual(Set(ReportReason.allCases.map(\.rawValue)),
                       ["spam", "harassment", "impersonation", "inappropriate_name", "other"])
        let data = try JSONEncoder().encode(["reason": ReportReason.inappropriateName])
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"reason":"inappropriate_name"}"#)
    }

    func testResponsesDecode() throws {
        let block = try JSONDecoder().decode(BlockResponse.self, from: Data(#"{"blocked":true}"#.utf8))
        XCTAssertTrue(block.blocked)
        let report = try JSONDecoder().decode(ReportResponse.self, from: Data(#"{"reported":true}"#.utf8))
        XCTAssertTrue(report.reported)
    }
}
