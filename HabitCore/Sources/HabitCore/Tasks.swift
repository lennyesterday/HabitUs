import Foundation

// Tasks of a member in the current round (R10 to R12, R19). Area B.

/// Done, failed and open tasks of `user` in the current round, and whether a photo is allowed today.
/// `firstRound` is the member's first round (R29): before it, checking in is not possible yet.
/// With fewer than `minimumPlayers` accepted members the challenge is on hold (R30).
public func taskStatus(user: UUID, group: HabitGroup, checkins: [Checkin], reactions: [Reaction],
                       memberCount: Int, firstRound: Int = 1, now: Date) -> TaskStatus {
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
        && current >= firstRound && !isOnHold(group, acceptedCount: memberCount, now: now)

    return TaskStatus(target: target, done: done, failed: failed, open: open, canCheckInToday: canCheckIn)
}

/// R17: my photo that the group just rejected and that I should take again, or nil.
/// Only while the round of the photo is still running and I still have an open task in it,
/// and only if it is my newest photo of the round, so it disappears once I took a new one.
/// After the round ends the task is simply missed.
public func photoToRetake(user: UUID, group: HabitGroup, checkins: [Checkin], reactions: [Reaction],
                          memberCount: Int, firstRound: Int = 1, now: Date) -> Checkin? {
    guard phase(of: group, now: now) == .active else { return nil }
    let current = currentRound(of: group, now: now)
    let newest = checkins
        .filter { $0.userId == user && $0.kind == .photo && round(of: $0.day, in: group) == current }
        .max { $0.createdAt < $1.createdAt }
    guard let newest, !isValid(newest, reactions: reactions, memberCount: memberCount) else { return nil }
    let status = taskStatus(user: user, group: group, checkins: checkins, reactions: reactions,
                            memberCount: memberCount, firstRound: firstRound, now: now)
    return status.open > 0 ? newest : nil
}

