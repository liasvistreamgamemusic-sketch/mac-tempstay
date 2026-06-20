import XCTest
@testable import Perch

final class SemanticVersionTests: XCTestCase {
    func testParsesPlainVersion() {
        let version = SemanticVersion("1.2.3")
        XCTAssertEqual(version?.major, 1)
        XCTAssertEqual(version?.minor, 2)
        XCTAssertEqual(version?.patch, 3)
    }

    func testParsesLeadingVAndMetadata() {
        XCTAssertEqual(SemanticVersion("v2.0"), SemanticVersion(major: 2, minor: 0, patch: 0))
        XCTAssertEqual(SemanticVersion("1.4.0-beta.1"), SemanticVersion(major: 1, minor: 4, patch: 0))
        XCTAssertEqual(SemanticVersion("1.0.0+build5"), SemanticVersion(major: 1, minor: 0, patch: 0))
    }

    func testRejectsNonNumericLead() {
        XCTAssertNil(SemanticVersion("latest"))
    }

    func testOrdering() {
        XCTAssertTrue(SemanticVersion("1.0.0")! < SemanticVersion("1.0.1")!)
        XCTAssertTrue(SemanticVersion("1.2.0")! < SemanticVersion("2.0.0")!)
        XCTAssertFalse(SemanticVersion("0.1.0")! < SemanticVersion("0.1.0")!)
    }
}
