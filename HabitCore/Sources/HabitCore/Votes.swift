import Foundation

// Like and X (R15 to R18). Area B.
// STUBS: the bodies are placeholders until the tests for each rule are written.

/// True if more than half of the other members pressed X (R17, R18).
public func xThresholdReached(xCount: Int, otherMembers: Int) -> Bool {
    // TODO(Area B): R17, R18
    return false
}

/// False once the X threshold is reached. The author's own X never counts (R15, R17, R18).
public func isValid(_ checkin: Checkin, reactions: [Reaction], memberCount: Int) -> Bool {
    // TODO(Area B): R15, R17, R18
    return true
}
