import Foundation

// Tasks of a member in the current round (R10 to R12, R19). Area B.
// STUBS: the bodies are placeholders until the tests for each rule are written.

/// Done, failed and open tasks of `user` in the current round, and whether a photo is allowed today.
public func taskStatus(user: UUID, group: HabitGroup, checkins: [Checkin], reactions: [Reaction],
                       memberCount: Int, now: Date) -> TaskStatus {
    // TODO(Area B): R10, R11, R12, R19
    return TaskStatus(target: group.target, done: 0, failed: 0, open: group.target, canCheckInToday: false)
}
