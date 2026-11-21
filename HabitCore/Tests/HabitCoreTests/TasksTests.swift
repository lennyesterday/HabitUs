import XCTest
@testable import HabitCore

// Area B. Checks: R11, R12, R19.
final class TasksTests: XCTestCase {
    let start = day(2026, 1, 5)   // a Monday

    func status(_ group: HabitGroup, _ checkins: [Checkin], _ reactions: [Reaction] = [],
                memberCount: Int = 3, now: Date) -> TaskStatus {
        taskStatus(user: owner, group: group, checkins: checkins, reactions: reactions,
                   memberCount: memberCount, now: now)
    }

    func testR11NoCheckinsMeansAllTasksOpen() {
        let s = status(makeGroup(), [], now: time(2026, 1, 5, 10))
        XCTAssertEqual(s, TaskStatus(target: 3, done: 0, failed: 0, open: 3, canCheckInToday: true))
    }

    func testR11ValidPhotoAndValidPauseCount() {
        let checkins = [makeCheckin(owner, on: start), makeCheckin(owner, on: addDays(1, to: start), kind: .pause)]
        let s = status(makeGroup(), checkins, now: time(2026, 1, 7, 10))
        XCTAssertEqual(s.done, 2)
        XCTAssertEqual(s.open, 1)
    }

    func testR11OnlyCheckinsOfThisRoundAndUserCount() {
        let lastRound = makeCheckin(owner, on: start)
        let someoneElse = makeCheckin(alice, on: addDays(7, to: start))
        let s = status(makeGroup(), [lastRound, someoneElse], now: time(2026, 1, 12, 10))
        XCTAssertEqual(s.done, 0)
    }

    func testR12WeeklySecondPhotoSameDayRefused() {
        let s = status(makeGroup(), [makeCheckin(owner, on: start)], now: time(2026, 1, 5, 20))
        XCTAssertFalse(s.canCheckInToday)
        let tomorrow = status(makeGroup(), [makeCheckin(owner, on: start)], now: time(2026, 1, 6, 8))
        XCTAssertTrue(tomorrow.canCheckInToday)
    }

    func testR12DailyTargetTwoAllowsTwoThenRefuses() {
        let group = makeGroup(target: 2, period: .day)
        let one = [makeCheckin(owner, on: start)]
        XCTAssertTrue(status(group, one, now: time(2026, 1, 5, 12)).canCheckInToday)
        let two = one + [makeCheckin(owner, on: start)]
        let s = status(group, two, now: time(2026, 1, 5, 13))
        XCTAssertEqual(s.done, 2)
        XCTAssertFalse(s.canCheckInToday)
    }

    func testR17AllowedAgainAfterPhotoBecameInvalid() {
        let photo = makeCheckin(owner, on: start)
        let s = status(makeGroup(), [photo], xs(on: photo, by: [alice, bob]), now: time(2026, 1, 5, 20))
        XCTAssertEqual(s.done, 0)
        XCTAssertEqual(s.open, 3)
        XCTAssertTrue(s.canCheckInToday)
    }

    func testR18RejectedPauseBlocksTheTask() {
        let pause = makeCheckin(owner, on: start, kind: .pause)
        let s = status(makeGroup(), [pause], xs(on: pause, by: [alice, bob]), now: time(2026, 1, 6, 10))
        XCTAssertEqual(s.done, 0)
        XCTAssertEqual(s.failed, 1)
        XCTAssertEqual(s.open, 2)
    }

    func testR12NoCheckinWhenAllTasksDone() {
        let checkins = (0..<3).map { makeCheckin(owner, on: addDays($0, to: start)) }
        let s = status(makeGroup(), checkins, now: time(2026, 1, 9, 10))
        XCTAssertEqual(s.open, 0)
        XCTAssertFalse(s.canCheckInToday)
    }

    func testR12NoCheckinWhenSessionEnded() {
        let group = makeGroup(endedEarlyAt: time(2026, 1, 6, 9))
        XCTAssertFalse(status(group, [], now: time(2026, 1, 6, 10)).canCheckInToday)
    }

    func testR12NoCheckinInTheLobby() {
        XCTAssertFalse(status(makeGroup(startedOn: nil), [], now: time(2026, 1, 6, 10)).canCheckInToday)
    }

    // MARK: R30 on hold, R29 joined later

    func testR30NoCheckInWhileOnHold() {
        XCTAssertFalse(status(makeGroup(), [], memberCount: 2, now: time(2026, 1, 5, 10)).canCheckInToday)
        XCTAssertTrue(status(makeGroup(), [], memberCount: 3, now: time(2026, 1, 5, 10)).canCheckInToday)
    }

    func testR29NoCheckInBeforeTheFirstRound() {
        let early = taskStatus(user: owner, group: makeGroup(), checkins: [], reactions: [], memberCount: 3,
                               firstRound: 2, now: time(2026, 1, 7, 10))     // round 1
        XCTAssertFalse(early.canCheckInToday)
        let onTime = taskStatus(user: owner, group: makeGroup(), checkins: [], reactions: [], memberCount: 3,
                                firstRound: 2, now: time(2026, 1, 12, 10))   // round 2
        XCTAssertTrue(onTime.canCheckInToday)
    }
}
