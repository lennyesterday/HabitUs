import XCTest
@testable import HabitCore

// Area C. Checks: R20 to R24.
final class ScoringTests: XCTestCase {

    // MARK: R20 to R23 points per round

    func testR21WorkedExample() {
        XCTAssertEqual(scoreRounds(donePerRound: [3, 3, 2, 3], target: 3), [75, 78, 40, 75])
    }

    func testR22PlayerWhoDoesEverything() {
        XCTAssertEqual(scoreRounds(donePerRound: Array(repeating: 3, count: 12), target: 3).reduce(0, +), 1035)
    }

    func testR22PlayerWhoMissesOneTaskInOneRound() {
        var rounds = Array(repeating: 3, count: 12)
        rounds[6] = 2
        XCTAssertEqual(scoreRounds(donePerRound: rounds, target: 3).reduce(0, +), 940)
    }

    func testR23PlayerWhoDoesTwoOfThreeEveryRound() {
        XCTAssertEqual(scoreRounds(donePerRound: Array(repeating: 2, count: 12), target: 3).reduce(0, +), 480)
    }

    func testR22BonusStopsAtFiftyPercent() {
        let points = scoreRounds(donePerRound: Array(repeating: 1, count: 8), target: 1)
        XCTAssertEqual(points, [25, 26, 27, 28, 29, 30, 30, 30])
    }

    func testR22BonusPercentForAStreak() {
        XCTAssertEqual(roundBonusPercent(completeRoundsInARow: 0), 0)
        XCTAssertEqual(roundBonusPercent(completeRoundsInARow: 1), 25)
        XCTAssertEqual(roundBonusPercent(completeRoundsInARow: 2), 30)
        XCTAssertEqual(roundBonusPercent(completeRoundsInARow: 6), 50)
        XCTAssertEqual(roundBonusPercent(completeRoundsInARow: 20), 50)
    }

    func testR20PointsPerRoundForTheChart() {
        // Round 1 complete (3 of 3), round 2 two of three: 75 and 40, like the worked example.
        let checkins = [0, 1, 2, 7, 8].map { makeCheckin(owner, on: addDays($0, to: start)) }
        let rows = leaderboard(group: makeGroup(target: 3), members: members, checkins: checkins,
                               reactions: [], now: time(2026, 1, 14, 12))
        let me = rows.first { $0.userId == owner }
        XCTAssertEqual(me?.pointsPerRound, [75, 40])
        XCTAssertEqual(me?.points, 115)
    }

    func testR23MissedTasksGiveZeroNeverNegative() {
        XCTAssertEqual(scoreRounds(donePerRound: [0, 0], target: 3), [0, 0])
    }

    func testR21BonusShareIsAboutThirtyPercentForEveryFrequency() {
        // Twelve weeks of a perfect player for 1 per day, 3 per week and 7 per week.
        let cases: [(done: [Int], target: Int)] = [
            (Array(repeating: 1, count: 84), 1),
            (Array(repeating: 3, count: 12), 3),
            (Array(repeating: 7, count: 12), 7),
        ]
        for c in cases {
            let total = Double(scoreRounds(donePerRound: c.done, target: c.target).reduce(0, +))
            let base = Double(c.done.reduce(0, +) * 20)
            let share = (total - base) / total
            XCTAssertTrue((0.25...0.35).contains(share), "target \(c.target): \(share)")
        }
    }

    // MARK: R24 leaderboard

    let start = day(2026, 1, 5)
    let members = [makeMember(owner, "Lenny"), makeMember(alice, "Alice"), makeMember(bob, "Bob")]

    func testR24SortedByPoints() {
        let checkins = [makeCheckin(alice, on: start), makeCheckin(alice, on: addDays(1, to: start)),
                        makeCheckin(owner, on: start)]
        let rows = leaderboard(group: makeGroup(), members: members, checkins: checkins, reactions: [],
                               now: time(2026, 1, 7, 12))
        XCTAssertEqual(rows.map(\.displayName), ["Alice", "Lenny", "Bob"])
        XCTAssertEqual(rows.map(\.points), [40, 20, 0])
    }

    func testR24TieFewerPausesFirstThenName() {
        let checkins = [makeCheckin(bob, on: start, kind: .pause), makeCheckin(owner, on: start),
                        makeCheckin(alice, on: start)]
        let rows = leaderboard(group: makeGroup(), members: members, checkins: checkins, reactions: [],
                               now: time(2026, 1, 7, 12))
        XCTAssertEqual(rows.map(\.displayName), ["Alice", "Lenny", "Bob"])
        XCTAssertEqual(rows.last?.pauses, 1)
    }

    func testR17InvalidPhotoLowersTheScore() {
        let photo = makeCheckin(owner, on: start)
        let before = leaderboard(group: makeGroup(), members: members, checkins: [photo], reactions: [],
                                 now: time(2026, 1, 7, 12))
        let after = leaderboard(group: makeGroup(), members: members, checkins: [photo],
                                reactions: xs(on: photo, by: [alice, bob]), now: time(2026, 1, 7, 12))
        XCTAssertEqual(before.first { $0.userId == owner }?.points, 20)
        XCTAssertEqual(after.first { $0.userId == owner }?.points, 0)
    }

    func testR22CompleteRoundsAndStreak() {
        let checkins = (0..<14).map { makeCheckin(owner, on: addDays($0, to: start)) }
        let group = makeGroup(target: 3)
        let rows = leaderboard(group: group, members: members, checkins: checkins, reactions: [],
                               now: time(2026, 1, 20, 12))   // round 3, nothing done yet
        let me = rows.first { $0.userId == owner }
        // Rounds 1 and 2 complete (only 3 of the 7 photos per week count): 75 + 78.
        XCTAssertEqual(me?.points, 153)
        XCTAssertEqual(me?.completeRounds, 2)
        XCTAssertEqual(me?.streak, 2)
    }

    func testR24OnlyAcceptedMembersAreRanked() {
        let all = members + [makeMember(carol, "Carol", status: .pending)]
        let rows = leaderboard(group: makeGroup(), members: all, checkins: [], reactions: [], now: time(2026, 1, 7, 12))
        XCTAssertEqual(rows.count, 3)
    }

    func testR9NoPointsAfterTheEnd() {
        let group = makeGroup(target: 1, period: .day, endedEarlyAt: time(2026, 1, 5, 20))
        let late = makeCheckin(owner, on: addDays(1, to: start))
        let rows = leaderboard(group: group, members: members, checkins: [late], reactions: [], now: time(2026, 1, 8, 12))
        XCTAssertEqual(rows.first { $0.userId == owner }?.points, 0)
    }
}
