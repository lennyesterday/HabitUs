import XCTest
@testable import HabitCore

// Area C. Checks: R9, R14 for all three periods.
final class RoundsTests: XCTestCase {
    let start = day(2026, 1, 5)

    // MARK: R9 round numbers

    func testR9WeeklyDaySevenIsRoundOneDayEightIsRoundTwo() {
        let group = makeGroup(period: .week, startedOn: start)
        XCTAssertEqual(round(of: start, in: group), 1)
        XCTAssertEqual(round(of: addDays(6, to: start), in: group), 1)
        XCTAssertEqual(round(of: addDays(7, to: start), in: group), 2)
    }

    func testR9DailyEveryDayIsANewRound() {
        let group = makeGroup(target: 1, period: .day, startedOn: start)
        XCTAssertEqual(round(of: start, in: group), 1)
        XCTAssertEqual(round(of: addDays(1, to: start), in: group), 2)
        XCTAssertEqual(round(of: addDays(9, to: start), in: group), 10)
    }

    func testR9MonthIsTwentyEightDays() {
        let group = makeGroup(period: .month, startedOn: start)
        XCTAssertEqual(round(of: addDays(27, to: start), in: group), 1)
        XCTAssertEqual(round(of: addDays(28, to: start), in: group), 2)
    }

    func testR9CurrentRoundFollowsNow() {
        let group = makeGroup(period: .week, startedOn: start)
        XCTAssertEqual(currentRound(of: group, now: time(2026, 1, 11, 23, 59)), 1)
        XCTAssertEqual(currentRound(of: group, now: time(2026, 1, 12, 0, 0)), 2)
    }

    // MARK: R9 phases

    func testR9LobbyBeforeStart() {
        XCTAssertEqual(phase(of: makeGroup(startedOn: nil), now: time(2026, 1, 5, 10)), .lobby)
    }

    func testR9EndDateKeepsOnlyFullRounds() {
        // 3 per week, end date 24 days after the start: 3 full rounds, ends after day 21.
        let group = makeGroup(period: .week, startedOn: start, endOn: addDays(24, to: start))
        XCTAssertEqual(phase(of: group, now: time(2026, 1, 25, 23)), .active)   // day 21
        XCTAssertEqual(phase(of: group, now: time(2026, 1, 26, 0)), .ended)     // day 22
        XCTAssertEqual(roundCount(of: group), 3)
    }

    func testR9OpenEndStillActiveAfterAYear() {
        let group = makeGroup(startedOn: start, endOn: nil)
        XCTAssertEqual(phase(of: group, now: time(2027, 1, 10, 12)), .active)
        XCTAssertNil(roundCount(of: group))
    }

    func testR8EndedOnceTheOwnerFinishes() {
        let group = makeGroup(startedOn: start, endedEarlyAt: time(2026, 2, 1, 18))
        XCTAssertEqual(phase(of: group, now: time(2026, 2, 1, 17)), .active)
        XCTAssertEqual(phase(of: group, now: time(2026, 2, 1, 18)), .ended)
    }

    // MARK: R9 start

    func testR9StartRefusedIfNoFullRoundFits() {
        let today = day(2026, 1, 5)
        XCTAssertFalse(canStart(makeGroup(period: .week, startedOn: nil, endOn: addDays(5, to: today)), today: today))
        XCTAssertTrue(canStart(makeGroup(period: .week, startedOn: nil, endOn: addDays(6, to: today)), today: today))
        XCTAssertTrue(canStart(makeGroup(period: .month, startedOn: nil, endOn: nil), today: today))
    }

    // MARK: R14 countdown

    func testR14TimeLeftUntilEndOfRound() {
        let group = makeGroup(period: .week, startedOn: start)
        // Round 1 ends at midnight between Sunday 11 and Monday 12.
        let left = timeLeft(in: group, now: time(2026, 1, 8, 22))
        XCTAssertEqual(left, (3 * 24 + 2) * 3600)
    }

    func testR14DailyRoundEndsAtMidnight() {
        let group = makeGroup(target: 1, period: .day, startedOn: start)
        XCTAssertEqual(timeLeft(in: group, now: time(2026, 1, 7, 23)), 3600)
    }

    func testR14NoTimeLeftInTheLobby() {
        XCTAssertEqual(timeLeft(in: makeGroup(startedOn: nil), now: time(2026, 1, 7, 23)), 0)
    }

    // MARK: Lisbon time

    func testR9LisbonDayAroundMidnight() {
        // 23:30 UTC on 31 Jan is still 31 Jan in Lisbon in winter (UTC+0) ...
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let winter = utc.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 23, minute: 30))!
        XCTAssertEqual(localDay(winter), day(2026, 1, 31))
        // ... but 23:30 UTC on 30 June is already 1 July in Lisbon in summer (UTC+1).
        let summer = utc.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 23, minute: 30))!
        XCTAssertEqual(localDay(summer), day(2026, 7, 1))
    }

    func testR9SummerTimeChangeDoesNotShiftRounds() {
        // Summer time starts on Sunday 29 March 2026. That day has only 23 hours.
        let group = makeGroup(target: 1, period: .day, startedOn: day(2026, 3, 28))
        XCTAssertEqual(round(of: day(2026, 3, 29), in: group), 2)
        XCTAssertEqual(round(of: day(2026, 3, 30), in: group), 3)
        XCTAssertEqual(timeLeft(in: group, now: time(2026, 3, 29, 0)), 23 * 3600)
    }
}
