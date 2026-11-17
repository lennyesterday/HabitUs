import Foundation

// Rounds and time (R9, R14). Area C.
// Every function takes the time as a parameter, so tests can pass any date.
// STUBS: the bodies are placeholders until the tests for each rule are written.

/// Lobby, active or ended (R8, R9).
public func phase(of group: HabitGroup, now: Date) -> Phase {
    // TODO(Area C): R8, R9
    return .lobby
}

/// The round number of `now`, starting at 1 (R9).
public func currentRound(of group: HabitGroup, now: Date) -> Int {
    // TODO(Area C): R9
    return 1
}

/// The round a check-in day belongs to, starting at 1 (R9).
public func round(of day: Date, in group: HabitGroup) -> Int {
    // TODO(Area C): R9
    return 1
}

/// Seconds until the current round ends (R14).
public func timeLeft(in group: HabitGroup, now: Date) -> TimeInterval {
    // TODO(Area C): R14
    return 0
}

/// True if at least one full round fits before the end date (R9).
public func canStart(_ group: HabitGroup, today: Date) -> Bool {
    // TODO(Area C): R9
    return false
}

/// The calendar day of `now` in Europe/Lisbon time, as midnight of that day (R9).
public func localDay(_ now: Date) -> Date {
    // TODO(Area C): R9
    return now
}
