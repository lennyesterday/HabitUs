import XCTest
@testable import HabitCore

// Area A. Checks: 6 characters, never 0, O, 1 or I (R4, S9).
final class InviteCodeTests: XCTestCase {
    func testR4CodeHasSixCharacters() {
        for _ in 0..<200 {
            XCTAssertEqual(InviteCode.generate().count, 6)
        }
    }

    func testR4CodeNeverContainsLookalikeCharacters() {
        for _ in 0..<500 {
            let code = InviteCode.generate()
            for bad in ["0", "O", "1", "I"] {
                XCTAssertFalse(code.contains(bad), "\(code) contains \(bad)")
            }
        }
    }

    func testS9CodesAreRandom() {
        let codes = Set((0..<100).map { _ in InviteCode.generate() })
        XCTAssertGreaterThan(codes.count, 95)
    }
}
