import XCTest
@testable import TermTPCore

final class SmokeTests: XCTestCase {
    func testLibraryVersionIsReadable() {
        XCTAssertEqual(TermTPVersion.current, "1.0")
    }
}
