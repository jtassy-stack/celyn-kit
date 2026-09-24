import XCTest
@testable import CelynKit

final class TransportConfigurationTests: XCTestCase {

    // MARK: Version headers

    func testLegacyInitKeepsBundleVersionWithoutClientHeader() {
        let client = CultureAPIClient(apiKey: "k", timeout: 20)
        XCTAssertEqual(client.versionHeaders, ["x-app-version": CultureAPIClient.appVersion])
        XCTAssertEqual(client.timeout, 20)
    }

    func testIdentifiedClientSendsClientAndVersion() {
        let client = CultureAPIClient(
            apiKey: "k",
            configuration: .init(timeout: 20, maxConnectionsPerHost: 6, clientIdentifier: "pause")
        )
        XCTAssertEqual(client.versionHeaders["x-client"], "pause")
        XCTAssertEqual(client.versionHeaders["x-app-version"], CultureAPIClient.appVersion)
    }

    func testAnonymousClientSendsNoVersion() {
        let client = CultureAPIClient(apiKey: "k", configuration: .init())
        XCTAssertTrue(client.versionHeaders.isEmpty)
    }

    // MARK: Date parsing

    private let ref = CultureAPIDateParsing.parse("2026-08-20T14:14:05Z")!

    func testISOVariants() {
        XCTAssertEqual(CultureAPIDateParsing.parse("2026-08-20T14:14:05.000Z"), ref)
        XCTAssertNotNil(ref)
    }

    func testPostgresVariants() {
        XCTAssertEqual(CultureAPIDateParsing.parse("2026-08-20 14:14:05+00"), ref)
        XCTAssertEqual(CultureAPIDateParsing.parse("2026-08-20 14:14:05"), ref)
    }

    func testPostgresFractional() throws {
        let micro = try XCTUnwrap(CultureAPIDateParsing.parse("2026-08-20 14:14:05.482497+00"))
        XCTAssertEqual(micro.timeIntervalSince(ref), 0.482, accuracy: 0.001)
        let tenth = try XCTUnwrap(CultureAPIDateParsing.parse("2026-08-20 14:14:05.4+00"))
        XCTAssertEqual(tenth.timeIntervalSince(ref), 0.4, accuracy: 0.001)
        XCTAssertEqual(CultureAPIDateParsing.parse("2026-08-20 14:14:05.4+0000"), tenth)
        XCTAssertEqual(CultureAPIDateParsing.parse("2026-08-20 14:14:05.4Z"), tenth)
    }

    func testPostgresFractionalRejectsBadInput() {
        XCTAssertNil(CultureAPIDateParsing.parse("2026-08-20 14:14:05.1234567+00"))
        XCTAssertNil(CultureAPIDateParsing.parse("2026-08-20 14:14:05.+00"))
        XCTAssertNil(CultureAPIDateParsing.parse("2026-08-20 14:14:05.4+02"))
    }

    /// Date-only stays anchored at noon UTC (existing behaviour, see dateOnly).
    func testDateOnlyIsNoonUTC() {
        XCTAssertEqual(
            CultureAPIDateParsing.parse("2026-08-20"),
            CultureAPIDateParsing.parse("2026-08-20T12:00:00Z")
        )
    }
}
