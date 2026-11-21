import Foundation

// Points, bonuses and leaderboard (R20 to R24). Area C.
// Points are always computed from check-ins, never stored (SPEC section 2).

/// The bonus in percent for a complete round, after this many complete rounds in a row
/// including this one (R21, R22): 0, 25, 30, 35, 40, 45, then 50 at most.
public func roundBonusPercent(completeRoundsInARow: Int) -> Int {
    guard completeRoundsInARow > 0 else { return 0 }
    return 25 + 5 * min(completeRoundsInARow - 1, 5)
}

/// Points per round, given the number of done tasks per round (R20 to R23).
public func scoreRounds(donePerRound: [Int], target: Int) -> [Int] {
    var streak = 0
    return donePerRound.map { done in
        let base = 20 * max(0, min(done, target))          // R20, R23
        guard done >= target else {
            streak = 0                                     // R22: incomplete round resets the streak
            return base
        }
        streak += 1
        let bonus = roundBonusPercent(completeRoundsInARow: streak)   // R21 +25 %, R22 +5 % more each
        return base * (100 + bonus) / 100
    }
}

/// The last round that counts for points: the current one, but never past the end.
func lastScoredRound(of group: HabitGroup, now: Date) -> Int {
    var last = currentRound(of: group, now: now)
    if let rounds = roundCount(of: group) {
        last = min(last, rounds)
    }
    if let endedEarlyAt = group.endedEarlyAt, now >= endedEarlyAt {
        last = min(last, round(of: endedEarlyAt, in: group))
    }
    return max(0, last)
}

/// Accepted members sorted by points, then fewer pauses, then name (R24).
/// Someone who joined later (R29) plays from their `firstRound`. For each round before it,
/// they get the average points of the members who played that round, rounded down.
/// Streak, complete rounds and the grade only look at the rounds they played themselves.
public func leaderboard(group: HabitGroup, members: [Member], checkins: [Checkin],
                        reactions: [Reaction], now: Date) -> [LeaderboardRow] {
    let accepted = members.filter { $0.status == .accepted }
    let lastRound = lastScoredRound(of: group, now: now)
    let endedEarlyAt = group.endedEarlyAt

    // Pass 1: everyone's own rounds. `points[r - 1]` is nil for a round before their first.
    struct Own {
        let member: Member
        let done: [Int]          // played rounds only, from firstRound to lastRound
        let points: [Int?]       // all rounds 1...lastRound
        let pauses: Int
    }
    let own = accepted.map { member -> Own in
        let first = member.firstRound
        let mine = checkins.filter { checkin in
            guard checkin.userId == member.userId else { return false }
            // Nothing counts that was posted after the owner finished.
            if let endedEarlyAt, checkin.createdAt > endedEarlyAt { return false }
            return true
        }
        var donePerRound = Array(repeating: 0, count: lastRound)
        for checkin in mine where isValid(checkin, reactions: reactions, memberCount: accepted.count) {
            let r = round(of: checkin.day, in: group)
            if r >= first && r <= lastRound {
                donePerRound[r - 1] += 1
            }
        }
        let played = first <= lastRound ? Array(donePerRound[(first - 1)...]) : []
        let playedPoints = scoreRounds(donePerRound: played, target: group.target)
        let skipped = min(first - 1, lastRound)
        let points: [Int?] = Array(repeating: nil, count: skipped) + playedPoints.map { Optional($0) }
        return Own(member: member, done: played.map { min($0, group.target) }, points: points,
                   pauses: mine.filter { $0.kind == .pause }.count)
    }

    // Pass 2: the average of each round over the members who played it.
    let average: [Int] = (0..<lastRound).map { index in
        let played = own.compactMap { $0.points[index] }
        return played.isEmpty ? 0 : played.reduce(0, +) / played.count
    }

    let rows = own.map { entry -> LeaderboardRow in
        let pointsPerRound = entry.points.enumerated().map { index, points in points ?? average[index] }
        let catchUp = entry.points.enumerated().reduce(0) { sum, item in
            item.element == nil ? sum + average[item.offset] : sum
        }
        let complete = entry.done.map { $0 >= group.target }

        // The streak counts complete rounds in a row up to now. A running round that is
        // not complete yet does not break it.
        var streakRounds = complete
        if phase(of: group, now: now) == .active, streakRounds.last == false {
            streakRounds.removeLast()
        }
        let streak = streakRounds.reversed().prefix { $0 }.count

        return LeaderboardRow(userId: entry.member.userId, displayName: entry.member.displayName,
                              photoPath: entry.member.photoPath,
                              points: pointsPerRound.reduce(0, +), completeRounds: complete.filter { $0 }.count,
                              streak: streak, pauses: entry.pauses,
                              pointsPerRound: pointsPerRound, donePerRound: entry.done,
                              firstRound: entry.member.firstRound, catchUpPoints: catchUp)
    }

    return rows.sorted { a, b in
        if a.points != b.points { return a.points > b.points }
        if a.pauses != b.pauses { return a.pauses < b.pauses }
        return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
    }
}

/// A to D from the share of tasks done in the given (finished) rounds:
/// A from 90 %, B from 70 %, C from 50 %, D below. nil before the first finished round.
/// Whole numbers only, so 90 % is exactly A and not lost to rounding.
public func grade(donePerRound: [Int], target: Int) -> Grade? {
    guard !donePerRound.isEmpty, target > 0 else { return nil }
    let done = donePerRound.reduce(0) { $0 + min($1, target) }
    let possible = donePerRound.count * target
    switch done * 100 {
    case (90 * possible)...: return .a
    case (70 * possible)...: return .b
    case (50 * possible)...: return .c
    default: return .d
    }
}
