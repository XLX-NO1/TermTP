import XCTest
@testable import TermCCore

final class SmokeTests: XCTestCase {
    func testLibraryVersionIsReadable() {
        XCTAssertEqual(TermCVersion.current, "1.0")
    }
}
