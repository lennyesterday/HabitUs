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

    // R18: a pause can be rejected for 48 hours after it was posted, even after its round ended.

    /// A pause posted on Sunday 11 Jan at 20:00, the last day of round 1 (weekly, starts 5 Jan).
    private func lateRoundOnePause() -> Checkin {
        var pause = makeCheckin(owner, on: day(2026, 1, 11), kind: .pause)
        pause.createdAt = time(2026, 1, 11, 20)
        return pause
    }

    func testR18PauseVotingEndsAfter48Hours() {
        let pause = lateRoundOnePause()
        XCTAssertEqual(pauseVotingEnds(pause), time(2026, 1, 13, 20))
    }

    func testR18PauseCanBeRejectedInTheNextRoundWithin48Hours() {
        let group = makeGroup()
        let pause = lateRoundOnePause()
        let now = time(2026, 1, 12, 18)   // round 2
        XCTAssertEqual(currentRound(of: group, now: now), 2)
        XCTAssertTrue(canReact(alice, to: pause, group: group, reactions: [], memberCount: 3, now: now))
    }

    func testR18PauseCannotBeRejectedAfter48Hours() {
        let group = makeGroup()
        let pause = lateRoundOnePause()
        XCTAssertTrue(canReact(alice, to: pause, group: group, reactions: [], memberCount: 3,
                               now: time(2026, 1, 13, 19, 59)))
        XCTAssertFalse(canReact(alice, to: pause, group: group, reactions: [], memberCount: 3,
                                now: time(2026, 1, 13, 20, 0)))
    }

    func testR18AuthorCannotRejectOwnPause() {
        let group = makeGroup()
        let pause = lateRoundOnePause()
        XCTAssertFalse(canReact(owner, to: pause, group: group, reactions: [], memberCount: 3,
                                now: time(2026, 1, 12, 18)))
    }

    func testR18RejectionInRoundTwoTakesRoundOnePointsAway() {
        let group = makeGroup(target: 1)
        let pause = lateRoundOnePause()
        let members = [makeMember(owner, "Lenny"), makeMember(alice, "Alice"), makeMember(bob, "Bob")]
        let now = time(2026, 1, 12, 18)   // round 2, inside the 48 hours

        let before = leaderboard(group: group, members: members, checkins: [pause], reactions: [], now: now)
        let ownerBefore = before.first { $0.userId == owner }
        XCTAssertEqual(ownerBefore?.pointsPerRound.first, 25, "accepted pause: 20 points + 25 % round bonus")

        let rejected = xs(on: pause, by: [alice, bob])
        let after = leaderboard(group: group, members: members, checkins: [pause], reactions: rejected, now: now)
        let ownerAfter = after.first { $0.userId == owner }
        XCTAssertEqual(ownerAfter?.pointsPerRound.first, 0, "rejected afterwards: points, bonus and streak gone")
        XCTAssertEqual(ownerAfter?.streak, 0)
    }

    func testR19PhotosStillFreezeAtTheEndOfTheirRound() {
        let group = makeGroup()
        var photo = makeCheckin(owner, on: day(2026, 1, 11))
        photo.createdAt = time(2026, 1, 11, 20)
        // Only 14 hours later, but already round 2: no more votes on the photo.
        XCTAssertFalse(canReact(alice, to: photo, group: group, reactions: [], memberCount: 3,
                                now: time(2026, 1, 12, 10)))
    }
}
