import XCTest
@testable import HabitCore

// Area A. Checks: R1, R4, R26 and the pause length.
// 28 per month and 7 per week are accepted, 8 per week and 29 per month are refused.
final class ValidationTests: XCTestCase {

    // MARK: R1 sign up

    func validSignUp(email: String = "lenny@example.com", password: String = "Secret123!",
                     repeated: String? = nil, name: String = "Lenny", terms: Bool = true) throws {
        try validateSignUp(email: email, password: password, repeatedPassword: repeated ?? password,
                           displayName: name, acceptedTerms: terms)
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
        XCTAssertThrowsError(try validSignUp(password: "Ab1!xyz"))
        XCTAssertNoThrow(try validSignUp(password: "Ab1!wxyz"))
    }

    func testR1PasswordNeedsEveryKindOfCharacter() {
        XCTAssertThrowsError(try validSignUp(password: "secret123!"), "no capital letter")
        XCTAssertThrowsError(try validSignUp(password: "SECRET123!"), "no small letter")
        XCTAssertThrowsError(try validSignUp(password: "SecretPass!"), "no number")
        XCTAssertThrowsError(try validSignUp(password: "Secret1234"), "no special character")
        XCTAssertNoThrow(try validSignUp(password: "Secret 12?"), "a space is fine as long as all rules are met")
    }

    func testR1PasswordMustBeTypedTheSameTwice() {
        XCTAssertThrowsError(try validSignUp(password: "Secret123!", repeated: "Secret123?")) { error in
            XCTAssertEqual((error as? RuleError)?.message, "The two passwords are not the same.")
        }
    }

    func testR1PasswordRulesShowWhatIsMissing() {
        let rules = passwordRules("abc")
        XCTAssertEqual(rules.count, 5)
        XCTAssertEqual(rules.filter(\.isMet).map(\.text), ["A small letter"])
        XCTAssertTrue(passwordRules("Secret123!").allSatisfy(\.isMet))
    }

    func testR1DisplayNameTwoToTwentyCharacters() {
        XCTAssertThrowsError(try validSignUp(name: "L"))
        XCTAssertThrowsError(try validSignUp(name: "   "))
        XCTAssertNoThrow(try validSignUp(name: "Lu"))
        XCTAssertNoThrow(try validSignUp(name: String(repeating: "a", count: 20)))
        XCTAssertThrowsError(try validSignUp(name: String(repeating: "a", count: 21)))
    }

    func testR1TermsMustBeTicked() {
        XCTAssertThrowsError(try validSignUp(terms: false))
    }

    func testR1ErrorHasReadableText() {
        XCTAssertThrowsError(try validSignUp(password: "short")) { error in
            XCTAssertEqual((error as? RuleError)?.message, "Your password still needs: at least 8 characters.")
        }
    }

    // MARK: R4 create group

    let today = day(2026, 1, 5)

    func validGroup(name: String = "Gym Crew", habit: String = "Gym", icon: String = "🏋️", target: Int = 3,
                    period: Period = .week, endOn: Date? = nil) throws {
        try validateGroup(name: name, habit: habit, icon: icon, target: target, period: period,
                          endOn: endOn, today: today)
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

    func testR4GroupIconIsExactlyOneEmoji() {
        XCTAssertNoThrow(try validGroup(icon: "📚"))
        XCTAssertNoThrow(try validGroup(icon: "🏋️"), "emoji with variation selector")
        XCTAssertNoThrow(try validGroup(icon: "👩‍👩‍👧"), "family emoji made of several parts")
        XCTAssertNoThrow(try validGroup(icon: "🇵🇹"), "flag")
        XCTAssertThrowsError(try validGroup(icon: ""))
        XCTAssertThrowsError(try validGroup(icon: "📚📚"), "two emojis")
        XCTAssertThrowsError(try validGroup(icon: "A"), "a letter")
        XCTAssertThrowsError(try validGroup(icon: "1"), "a digit")
    }

    func testR4OpenEndIsAccepted() {
        XCTAssertNoThrow(try validGroup(endOn: nil))
    }

    // MARK: Signature (drawn by hand, stored as a small PNG)

    let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    func testR4DrawnSignatureIsAccepted() {
        XCTAssertNoThrow(try validateSignatureImage(pngHeader + Data(repeating: 1, count: 2_000)))
    }

    func testR4SignatureIsRequired() {
        XCTAssertThrowsError(try validateSignatureImage(Data()))
    }

    func testR4SignatureMustBeAPNG() {
        XCTAssertThrowsError(try validateSignatureImage(Data("Lenny".utf8)))
    }

    func testR4SignatureHasASizeLimit() {
        XCTAssertNoThrow(try validateSignatureImage(pngHeader + Data(repeating: 1, count: 39_000)))
        XCTAssertThrowsError(try validateSignatureImage(pngHeader + Data(repeating: 1, count: 40_000)))
    }

    // MARK: R26 messages

    func testR26MessageOneToFiveHundredCharacters() {
        XCTAssertThrowsError(try validateMessage(""))
        XCTAssertThrowsError(try validateMessage("   "))
        XCTAssertNoThrow(try validateMessage("let's go"))
        XCTAssertNoThrow(try validateMessage(String(repeating: "a", count: 500)))
        XCTAssertThrowsError(try validateMessage(String(repeating: "a", count: 501)))
    }

    // MARK: R1 email confirmation code

    func testR1EmailCodeIsSixToTenDigits() {
        XCTAssertNoThrow(try validateEmailCode("123456"))
        XCTAssertNoThrow(try validateEmailCode(" 123 456 "), "spaces from copy and paste are ignored")
        XCTAssertNoThrow(try validateEmailCode("1234567890"))
        XCTAssertThrowsError(try validateEmailCode(""))
        XCTAssertThrowsError(try validateEmailCode("12345"))
        XCTAssertThrowsError(try validateEmailCode("12345678901"))
        XCTAssertThrowsError(try validateEmailCode("12a456"))
    }

    func testR1EmailCodeIsCleaned() throws {
        XCTAssertEqual(try validateEmailCode(" 123 456 "), "123456")
    }

    // MARK: R1 forgot password

    func testR1ResetNeedsAValidEmail() {
        XCTAssertNoThrow(try validateEmail(" lenny@example.com "))
        XCTAssertThrowsError(try validateEmail("lenny"))
        XCTAssertThrowsError(try validateEmail("@example.com"))
        XCTAssertThrowsError(try validateEmail("lenny@example."))
    }

    func testR1NewPasswordFollowsTheSameRules() {
        XCTAssertNoThrow(try validatePassword("Secret123!", repeated: "Secret123!"))
        XCTAssertThrowsError(try validatePassword("12345678", repeated: "12345678"))
        XCTAssertThrowsError(try validatePassword("Secret123!", repeated: ""))
    }

    // MARK: R26 GIFs in the chat

    func testR26GifMustComeFromGiphy() {
        XCTAssertNoThrow(try validateGifURL("https://media2.giphy.com/media/abc123/200w.gif?cid=x&rid=200w.gif"))
        XCTAssertNoThrow(try validateGifURL("https://media.giphy.com/media/abc123/giphy.gif"))
        XCTAssertNoThrow(try validateGifURL("https://i.giphy.com/abc123.gif"))
    }

    func testR26GifFromAnywhereElseIsRefused() {
        XCTAssertThrowsError(try validateGifURL("http://media.giphy.com/media/abc/200w.gif"), "no plain http")
        XCTAssertThrowsError(try validateGifURL("https://evil.com/media.giphy.com/x.gif"))
        XCTAssertThrowsError(try validateGifURL("https://media.giphy.com.evil.com/x.gif"))
        XCTAssertThrowsError(try validateGifURL("https://giphy.com/gifs/abc"), "a web page, not a GIF")
        XCTAssertThrowsError(try validateGifURL("not a url"))
        XCTAssertThrowsError(try validateGifURL("https://media.giphy.com/" + String(repeating: "a", count: 500)))
    }

    // MARK: R18 pause reason

    func testR18PauseReasonOneToTwoHundredCharacters() {
        XCTAssertThrowsError(try validatePauseReason(""))
        XCTAssertNoThrow(try validatePauseReason("sick"))
        XCTAssertNoThrow(try validatePauseReason(String(repeating: "a", count: 200)))
        XCTAssertThrowsError(try validatePauseReason(String(repeating: "a", count: 201)))
    }

    // MARK: R31 delete account

    func testR31DeleteAccountNeedsTheWordDelete() {
        XCTAssertNoThrow(try validateAccountDeletion("DELETE"))
        XCTAssertNoThrow(try validateAccountDeletion("  delete \n"), "case and spaces do not matter")
        XCTAssertThrowsError(try validateAccountDeletion(""))
        XCTAssertThrowsError(try validateAccountDeletion("DELET"))
        XCTAssertThrowsError(try validateAccountDeletion("yes"))
    }
}
