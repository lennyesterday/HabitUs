import Foundation

// Tasks of a member in the current round (R10 to R12, R19). Area B.

/// Done, failed and open tasks of `user` in the current round, and whether a photo is allowed today.
public func taskStatus(user: UUID, group: HabitGroup, checkins: [Checkin], reactions: [Reaction],
                       memberCount: Int, now: Date) -> TaskStatus {
    let target = group.target
    let current = currentRound(of: group, now: now)
    let mine = checkins.filter { $0.userId == user && round(of: $0.day, in: group) == current }

    // R11: a counted check-in is a valid photo or a valid pause.
    let counted = mine.filter { isValid($0, reactions: reactions, memberCount: memberCount) }
    // R18: a rejected pause fails its task for this round.
    let rejectedPauses = mine.filter {
        $0.kind == .pause && !isValid($0, reactions: reactions, memberCount: memberCount)
    }

    let done = min(target, counted.count)
    let failed = min(target - done, rejectedPauses.count)
    let open = target - done - failed

    // R12: weekly and monthly need a different day for each photo. Daily allows several.
    let today = localDay(now)
    let photoToday = counted.contains { $0.kind == .photo && localDay($0.day) == today }
    let dayIsFree = group.period == .day || !photoToday
    let canCheckIn = phase(of: group, now: now) == .active && open > 0 && dayIsFree

    return TaskStatus(target: target, done: done, failed: failed, open: open, canCheckInToday: canCheckIn)
}
