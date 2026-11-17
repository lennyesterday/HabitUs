import XCTest
@testable import HabitCore

// Area A. Checks: R1, R4, R26 and the pause length.
// 28 per month and 7 per week are accepted, 8 per week and 29 per month are refused.
final class ValidationTests: XCTestCase {

    // MARK: R1 sign up

    func validSignUp(email: String = "lenny@example.com", password: String = "secret123",
                     name: String = "Lenny", avatar: String = "🏋️", terms: Bool = true) throws {
        try validateSignUp(email: email, password: password, displayName: name, avatar: avatar, acceptedTerms: terms)
    }

    func testR1ValidSignUpIsAccepted() {
        XCTAssertNoThrow(try validSignUp())
    }

    func testR1EmailMustLookLikeAnEmail() {
        XCTAssertThrowsError(try validSignUp(email: "lenny"))
        XCTAssertThrowsError(try validSignUp(email: "lenny@"))
        XCTAssertThrowsError(try validSignUp(email: ""))
    }

    func testR1PasswordNeedsEightCharacters() {
        XCTAssertThrowsError(try validSignUp(password: "1234567"))
        XCTAssertNoThrow(try validSignUp(password: "12345678"))
    }

    func testR1DisplayNameTwoToTwentyCharacters() {
        XCTAssertThrowsError(try validSignUp(name: "L"))
        XCTAssertThrowsError(try validSignUp(name: "   "))
        XCTAssertNoThrow(try validSignUp(name: "Lu"))
        XCTAssertNoThrow(try validSignUp(name: String(repeating: "a", count: 20)))
        XCTAssertThrowsError(try validSignUp(name: String(repeating: "a", count: 21)))
    }

    func testR1AvatarIsRequired() {
        XCTAssertThrowsError(try validSignUp(avatar: ""))
    }

    func testR1TermsMustBeTicked() {
        XCTAssertThrowsError(try validSignUp(terms: false))
    }

    func testR1ErrorHasReadableText() {
        XCTAssertThrowsError(try validSignUp(password: "short")) { error in
            XCTAssertEqual((error as? RuleError)?.message, "The password needs at least 8 characters.")
        }
    }

    // MARK: R4 create group

    let today = day(2026, 1, 5)

    func validGroup(name: String = "Gym Crew", habit: String = "Gym", target: Int = 3,
                    period: Period = .week, endOn: Date? = nil) throws {
        try validateGroup(name: name, habit: habit, target: target, period: period, endOn: endOn, today: today)
    }

    func testR4ValidGroupIsAccepted() {
        XCTAssertNoThrow(try validGroup())
    }

    func testR4NameAndHabitAreRequired() {
        XCTAssertThrowsError(try validGroup(name: " "))
        XCTAssertThrowsError(try validGroup(habit: ""))
        XCTAssertThrowsError(try validGroup(name: String(repeating: "a", count: 41)))
        XCTAssertThrowsError(try validGroup(habit: String(repeating: "a", count: 21)))
    }

    func testR4TargetLimitsPerPeriod() {
        XCTAssertNoThrow(try validGroup(target: 10, period: .day))
        XCTAssertThrowsError(try validGroup(target: 11, period: .day))
        XCTAssertNoThrow(try validGroup(target: 7, period: .week))
        XCTAssertThrowsError(try validGroup(target: 8, period: .week))
        XCTAssertNoThrow(try validGroup(target: 28, period: .month))
        XCTAssertThrowsError(try validGroup(target: 29, period: .month))
        XCTAssertThrowsError(try validGroup(target: 0, period: .week))
    }

    func testR4EndDateMustLeaveRoomForOneFullRound() {
        // A week starting today ends after day 7, so the end date must be today + 6 or later.
        XCTAssertNoThrow(try validGroup(period: .week, endOn: addDays(6, to: today)))
        XCTAssertThrowsError(try validGroup(period: .week, endOn: addDays(5, to: today)))
        XCTAssertThrowsError(try validGroup(period: .day, endOn: addDays(-1, to: today)))
        XCTAssertNoThrow(try validGroup(target: 1, period: .day, endOn: today))
    }

    func testR4OpenEndIsAccepted() {
        XCTAssertNoThrow(try validGroup(endOn: nil))
    }

    // MARK: Signature

    func testR4SignatureIsRequired() {
        XCTAssertThrowsError(try validateSignature("  "))
        XCTAssertNoThrow(try validateSignature("Lenny"))
    }

    // MARK: R26 messages

    func testR26MessageOneToFiveHundredCharacters() {
        XCTAssertThrowsError(try validateMessage(""))
        XCTAssertThrowsError(try validateMessage("   "))
        XCTAssertNoThrow(try validateMessage("let's go"))
        XCTAssertNoThrow(try validateMessage(String(repeating: "a", count: 500)))
        XCTAssertThrowsError(try validateMessage(String(repeating: "a", count: 501)))
    }

    // MARK: R18 pause reason

    func testR18PauseReasonOneToTwoHundredCharacters() {
        XCTAssertThrowsError(try validatePauseReason(""))
        XCTAssertNoThrow(try validatePauseReason("sick"))
        XCTAssertNoThrow(try validatePauseReason(String(repeating: "a", count: 200)))
        XCTAssertThrowsError(try validatePauseReason(String(repeating: "a", count: 201)))
    }
}
