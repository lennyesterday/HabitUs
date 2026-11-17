import Foundation

// Points, bonuses and leaderboard (R20 to R24). Area C.
// Points are always computed from check-ins, never stored (SPEC section 2).
// STUBS: the bodies are placeholders until the tests for each rule are written.

/// Points per round, given the number of done tasks per round (R20 to R23).
public func scoreRounds(donePerRound: [Int], target: Int) -> [Int] {
    // TODO(Area C): R20, R21, R22, R23
    return donePerRound.map { _ in 0 }
}

/// Accepted members sorted by points, then fewer pauses, then name (R24).
public func leaderboard(group: HabitGroup, members: [Member], checkins: [Checkin],
                        reactions: [Reaction], now: Date) -> [LeaderboardRow] {
    // TODO(Area C): R24
    return []
}
