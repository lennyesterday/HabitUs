import XCTest
@testable import HabitCore

// Area B. Checks: R15 to R18. The table in SPEC section 3 row by row. The author's own X does not count.
final class VotesTests: XCTestCase {

    // The table: members in the group -> X needed (other members = members - 1).
    func testR17ThresholdTable() {
        let table: [(members: Int, needed: Int)] = [(3, 2), (4, 2), (5, 3), (6, 3)]
        for row in table {
            let others = row.members - 1
            XCTAssertFalse(xThresholdReached(xCount: row.needed - 1, otherMembers: others), "\(row.members) members")
            XCTAssertTrue(xThresholdReached(xCount: row.needed, otherMembers: others), "\(row.members) members")
        }
    }

    func testR17PhotoInvalidWhenMoreThanHalfX() {
        let photo = makeCheckin(owner, on: day(2026, 1, 5))
        XCTAssertTrue(isValid(photo, reactions: xs(on: photo, by: [alice]), memberCount: 3))
        XCTAssertFalse(isValid(photo, reactions: xs(on: photo, by: [alice, bob]), memberCount: 3))
    }

    func testR15AuthorsOwnXDoesNotCount() {
        let photo = makeCheckin(owner, on: day(2026, 1, 5))
        XCTAssertTrue(isValid(photo, reactions: xs(on: photo, by: [owner, alice]), memberCount: 3))
    }

    func testR16LikesNeverChangeValidity() {
        let photo = makeCheckin(owner, on: day(2026, 1, 5))
        let likes = [alice, bob].map { Reaction(checkinId: photo.id, userId: $0, kind: .like) }
        XCTAssertTrue(isValid(photo, reactions: likes, memberCount: 3))
    }

    func testR17XOnOtherCheckinsDoNotCount() {
        let photo = makeCheckin(owner, on: day(2026, 1, 5))
        let other = makeCheckin(alice, on: day(2026, 1, 5))
        XCTAssertTrue(isValid(photo, reactions: xs(on: other, by: [bob, carol]), memberCount: 4))
    }

    func testR18PauseRejectedWithTheSameRule() {
        let pause = makeCheckin(owner, on: day(2026, 1, 5), kind: .pause)
        XCTAssertTrue(isValid(pause, reactions: [], memberCount: 3), "a pause is accepted by default")
        XCTAssertFalse(isValid(pause, reactions: xs(on: pause, by: [alice, bob]), memberCount: 3))
    }

    // canReact: who may press like or X, and when (R15, R17, R19).

    func testR15OtherMemberCanReactWhileRoundRuns() {
        let group = makeGroup()
        let photo = makeCheckin(owner, on: day(2026, 1, 6))
        XCTAssertTrue(canReact(alice, to: photo, group: group, reactions: [], memberCount: 3,
                               now: time(2026, 1, 7, 12)))
    }

    func testR15AuthorCannotReactToOwnCheckin() {
        let group = makeGroup()
        let photo = makeCheckin(owner, on: day(2026, 1, 6))
        XCTAssertFalse(canReact(owner, to: photo, group: group, reactions: [], memberCount: 3,
                                now: time(2026, 1, 7, 12)))
    }

    func testR17NoReactionsOnceInvalid() {
        let group = makeGroup()
        let photo = makeCheckin(owner, on: day(2026, 1, 6))
        let reactions = xs(on: photo, by: [alice, bob])
        XCTAssertFalse(canReact(alice, to: photo, group: group, reactions: reactions, memberCount: 3,
                                now: time(2026, 1, 7, 12)), "invalid is final, the X cannot be taken back")
    }

    func testR19NoReactionsAfterTheRoundEnded() {
        let group = makeGroup()   // weekly, starts 5 Jan, so round 1 is 5 to 11 Jan
        let photo = makeCheckin(owner, on: day(2026, 1, 6))
        XCTAssertTrue(canReact(alice, to: photo, group: group, reactions: [], memberCount: 3,
                               now: time(2026, 1, 11, 23, 59)))
        XCTAssertFalse(canReact(alice, to: photo, group: group, reactions: [], memberCount: 3,
                                now: time(2026, 1, 12, 0, 1)))
    }

    func testR19NoReactionsAfterTheChallengeWasFinished() {
        let group = makeGroup(endedEarlyAt: time(2026, 1, 7, 10))
        let photo = makeCheckin(owner, on: day(2026, 1, 6))
        XCTAssertFalse(canReact(alice, to: photo, group: group, reactions: [], memberCount: 3,
                                now: time(2026, 1, 7, 12)))
    }
}
