import XCTest
@testable import TermCCore

final class SmokeTests: XCTestCase {
    func testLibraryVersionIsReadable() {
        XCTAssertEqual(TermCVersion.current, "0.1.0")
    }
}
