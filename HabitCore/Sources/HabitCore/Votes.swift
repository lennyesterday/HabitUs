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
