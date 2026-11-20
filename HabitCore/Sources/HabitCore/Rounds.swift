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
/// With fewer, a photo can hardly be voted invalid any more, so the game stops making sense.
public let minimumPlayers = 3

/// R28: true if the challenge ends when one accepted member leaves now. Only a running
/// challenge ends, and only when fewer than `minimumPlayers` would be left. In the lobby
/// people can come and go. The database function `leave_group` does the same check.
public func leavingEndsChallenge(_ group: HabitGroup, acceptedBefore: Int, now: Date) -> Bool {
    phase(of: group, now: now) == .active && acceptedBefore - 1 < minimumPlayers
}

/// True if at least one full round fits before the end date when starting `today` (R9).
public func canStart(_ group: HabitGroup, today: Date) -> Bool {
    guard let endOn = group.endOn else { return true }
    return daysBetween(today, endOn) + 1 >= group.period.rawValue
}
