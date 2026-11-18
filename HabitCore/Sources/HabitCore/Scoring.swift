import Foundation

// Points, bonuses and leaderboard (R20 to R24). Area C.
// Points are always computed from check-ins, never stored (SPEC section 2).

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
        let bonus = 25 + 5 * min(streak - 1, 5)            // R21 +25 %, R22 +5 % more each, max +50 %
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
public func leaderboard(group: HabitGroup, members: [Member], checkins: [Checkin],
                        reactions: [Reaction], now: Date) -> [LeaderboardRow] {
    let accepted = members.filter { $0.status == .accepted }
    let lastRound = lastScoredRound(of: group, now: now)
    let endedEarlyAt = group.endedEarlyAt

    let rows = accepted.map { member -> LeaderboardRow in
        let mine = checkins.filter { checkin in
            guard checkin.userId == member.userId else { return false }
            // Nothing counts that was posted after the owner finished.
            if let endedEarlyAt, checkin.createdAt > endedEarlyAt { return false }
            return true
        }
        var donePerRound = Array(repeating: 0, count: lastRound)
        for checkin in mine where isValid(checkin, reactions: reactions, memberCount: accepted.count) {
            let r = round(of: checkin.day, in: group)
            if r >= 1 && r <= lastRound {
                donePerRound[r - 1] += 1
            }
        }
        let points = scoreRounds(donePerRound: donePerRound, target: group.target).reduce(0, +)
        let complete = donePerRound.map { $0 >= group.target }

        // The streak counts complete rounds in a row up to now. A running round that is
        // not complete yet does not break it.
        var streakRounds = complete
        if phase(of: group, now: now) == .active, streakRounds.last == false {
            streakRounds.removeLast()
        }
        let streak = streakRounds.reversed().prefix { $0 }.count

        return LeaderboardRow(userId: member.userId, displayName: member.displayName, photoPath: member.photoPath,
                              points: points, completeRounds: complete.filter { $0 }.count, streak: streak,
                              pauses: mine.filter { $0.kind == .pause }.count)
    }

    return rows.sorted { a, b in
        if a.points != b.points { return a.points > b.points }
        if a.pauses != b.pauses { return a.pauses < b.pauses }
        return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
    }
}
