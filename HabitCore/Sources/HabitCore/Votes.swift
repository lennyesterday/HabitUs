import Foundation

// Like and X (R15 to R18). Area B.

/// True if more than half of the other members pressed X (R17, R18).
public func xThresholdReached(xCount: Int, otherMembers: Int) -> Bool {
    xCount * 2 > otherMembers
}

/// False once the X threshold is reached. The author's own X never counts (R15, R17, R18).
/// Likes never change anything (R16).
public func isValid(_ checkin: Checkin, reactions: [Reaction], memberCount: Int) -> Bool {
    let xCount = reactions.filter {
        $0.checkinId == checkin.id && $0.kind == .x && $0.userId != checkin.userId
    }.count
    return !xThresholdReached(xCount: xCount, otherMembers: memberCount - 1)
}

/// R18: how long the other members can reject a pause after it was posted.
public let pauseVotingWindow: TimeInterval = 48 * 3600

/// R18: the moment the pause becomes final, 48 hours after it was posted.
public func pauseVotingEnds(_ pause: Checkin) -> Date {
    pause.createdAt.addingTimeInterval(pauseVotingWindow)
}

/// True if `user` may give, change or remove a like or X on this check-in right now.
/// Never on your own check-in (R15), not once it is invalid, because invalid is final (R17).
/// A pause stays open for 48 hours after it was posted, even after its round ended (R18).
/// A photo only while the session runs and its round is the current one (R19).
public func canReact(_ user: UUID, to checkin: Checkin, group: HabitGroup, reactions: [Reaction],
                     memberCount: Int, now: Date) -> Bool {
    guard user != checkin.userId, isValid(checkin, reactions: reactions, memberCount: memberCount) else {
        return false
    }
    switch checkin.kind {
    case .pause:
        return now < pauseVotingEnds(checkin)
    case .photo:
        return phase(of: group, now: now) == .active
            && round(of: checkin.day, in: group) == currentRound(of: group, now: now)
    }
}
