import Foundation

// Input checks for every form. Each one throws a RuleError with a readable text. Area A.
// STUBS: the bodies are placeholders until the tests for each rule are written.

/// R1: email, password of at least 8 characters, name of 2 to 20 characters, avatar, terms ticked.
public func validateSignUp(email: String, password: String, displayName: String,
                           avatar: String, acceptedTerms: Bool) throws {
    // TODO(Area A): R1
}

/// R4: name, habit, how often (1 up to `period.maxTarget`), and an end date after today if there is one.
public func validateGroup(name: String, habit: String, target: Int, period: Period,
                          endOn: Date?, today: Date) throws {
    // TODO(Area A): R4
}

/// R26: 1 to 500 characters.
public func validateMessage(_ text: String) throws {
    // TODO(Area A): R26
}

/// R18: a reason of 1 to 200 characters.
public func validatePauseReason(_ reason: String) throws {
    // TODO(Area A): R18
}
