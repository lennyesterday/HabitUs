import Foundation

// Rounds and time (R9, R14). Area C.
// Every function takes the time as a parameter, so tests can pass any date.
// All days are calendar days in Europe/Lisbon, so summer time never shifts a round.

/// The calendar we count days with.
let lisbonCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .current
    return calendar
}()

/// The calendar day of `now` in Europe/Lisbon time, as midnight of that day (R9).
public func localDay(_ now: Date) -> Date {
    lisbonCalendar.startOfDay(for: now)
}

/// Whole calendar days from `from` to `to`, counted in Lisbon. Same day = 0.
func daysBetween(_ from: Date, _ to: Date) -> Int {
    lisbonCalendar.dateComponents([.day], from: localDay(from), to: localDay(to)).day ?? 0
}

/// Lisbon midnight `days` days after `date`.
func adding(days: Int, to date: Date) -> Date {
    lisbonCalendar.date(byAdding: .day, value: days, to: localDay(date)) ?? date
}

/// How many full rounds fit between `start` and the end date. nil for open end (R9).
public func roundCount(of group: HabitGroup) -> Int? {
    guard let endOn = group.endOn, let start = group.startedOn else { return nil }
    return (daysBetween(start, endOn) + 1) / group.period.rawValue
}

/// Lobby, active or ended (R8, R9).
public func phase(of group: HabitGroup, now: Date) -> Phase {
    guard let start = group.startedOn else { return .lobby }
    if let endedEarlyAt = group.endedEarlyAt, now >= endedEarlyAt {
        return .ended
    }
    if let rounds = roundCount(of: group) {
        // The challenge ends at midnight after the last full round.
        let end = adding(days: rounds * group.period.rawValue, to: start)
        if now >= end { return .ended }
    }
    return .active
}

/// The round a check-in day belongs to, starting at 1 (R9). 0 before the start.
public func round(of day: Date, in group: HabitGroup) -> Int {
    guard let start = group.startedOn else { return 0 }
    let days = daysBetween(start, day)
    guard days >= 0 else { return 0 }
    return days / group.period.rawValue + 1
}

/// The round number of `now`, starting at 1 (R9).
public func currentRound(of group: HabitGroup, now: Date) -> Int {
    round(of: now, in: group)
}

/// Seconds until the current round ends (R14). 0 in the lobby.
public func timeLeft(in group: HabitGroup, now: Date) -> TimeInterval {
    guard let start = group.startedOn else { return 0 }
    let current = currentRound(of: group, now: now)
    guard current > 0 else { return 0 }
    let end = adding(days: current * group.period.rawValue, to: start)
    return max(0, end.timeIntervalSince(now))
}

/// R7: a session needs at least this many accepted members to start, and to keep running.
/// With fewer, a photo can hardly be voted invalid any more.
public let minimumPlayers = 3

/// R30: a running challenge with fewer than `minimumPlayers` is on hold. Nobody can check in
/// until enough people joined again (R29). The rounds keep counting, for everyone the same.
public func isOnHold(_ group: HabitGroup, acceptedCount: Int, now: Date) -> Bool {
    phase(of: group, now: now) == .active && acceptedCount < minimumPlayers
}

/// R30: true if one accepted member leaving now puts the running challenge on hold.
public func leavingPutsOnHold(_ group: HabitGroup, acceptedBefore: Int, now: Date) -> Bool {
    isOnHold(group, acceptedCount: acceptedBefore - 1, now: now)
}

/// R29: the first round of someone accepted now. In the lobby everyone starts in round 1.
/// In a running challenge the new member starts with the next round, so nobody has to finish
/// half a round. The database trigger in 007_late_join.sql computes the same.
public func firstRound(acceptedAt now: Date, in group: HabitGroup) -> Int {
    guard phase(of: group, now: now) == .active else { return 1 }
    return currentRound(of: group, now: now) + 1
}

/// True if at least one full round fits before the end date when starting `today` (R9).
public func canStart(_ group: HabitGroup, today: Date) -> Bool {
    guard let endOn = group.endOn else { return true }
    return daysBetween(today, endOn) + 1 >= group.period.rawValue
}
