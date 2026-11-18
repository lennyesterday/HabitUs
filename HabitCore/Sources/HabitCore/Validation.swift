import Foundation

// Input checks for every form. Each one throws a RuleError with a readable text. Area A.

private func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// R1: email, password of at least 8 characters, name of 2 to 20 characters, avatar, terms ticked.
public func validateSignUp(email: String, password: String, displayName: String,
                           avatar: String, acceptedTerms: Bool) throws {
    let email = trimmed(email)
    let parts = email.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."), !parts[1].hasSuffix(".") else {
        throw RuleError("Please enter a valid email address.")
    }
    guard password.count >= 8 else {
        throw RuleError("The password needs at least 8 characters.")
    }
    guard (2...20).contains(trimmed(displayName).count) else {
        throw RuleError("Your name needs 2 to 20 characters.")
    }
    guard !trimmed(avatar).isEmpty else {
        throw RuleError("Please pick an avatar.")
    }
    guard acceptedTerms else {
        throw RuleError("Please accept the terms.")
    }
}

/// R4: name (1 to 40), habit (1 to 20), how often (1 up to `period.maxTarget`),
/// and an end date that leaves room for at least one full round from today.
public func validateGroup(name: String, habit: String, target: Int, period: Period,
                          endOn: Date?, today: Date) throws {
    guard (1...40).contains(trimmed(name).count) else {
        throw RuleError("The group name needs 1 to 40 characters.")
    }
    guard (1...20).contains(trimmed(habit).count) else {
        throw RuleError("The habit needs 1 to 20 characters, for example \"Gym\".")
    }
    guard (1...period.maxTarget).contains(target) else {
        throw RuleError("How often must be between 1 and \(period.maxTarget).")
    }
    if let endOn, daysBetween(today, endOn) + 1 < period.rawValue {
        throw RuleError("The end date is too early. At least one full round has to fit.")
    }
}

/// R4, R5: the typed name under the contract.
public func validateSignature(_ signature: String) throws {
    guard (1...40).contains(trimmed(signature).count) else {
        throw RuleError("Please sign with your name.")
    }
}

/// R26: 1 to 500 characters.
public func validateMessage(_ text: String) throws {
    guard (1...500).contains(trimmed(text).count) else {
        throw RuleError("A message needs 1 to 500 characters.")
    }
}

/// R18: a reason of 1 to 200 characters.
public func validatePauseReason(_ reason: String) throws {
    guard (1...200).contains(trimmed(reason).count) else {
        throw RuleError("Please give a reason with up to 200 characters.")
    }
}

/// R26: a GIF in the chat must be a .gif file on GIPHY's media servers, over https.
/// So nobody can post links to other websites that every member's phone would then load.
public func validateGifURL(_ text: String) throws {
    guard text.count <= 500,
          let url = URL(string: text),
          url.scheme == "https",
          let host = url.host,
          host == "i.giphy.com" || host.range(of: #"^media[0-9]*\.giphy\.com$"#, options: .regularExpression) != nil,
          url.path.hasSuffix(".gif") else {
        throw RuleError("Only GIFs from GIPHY can be sent.")
    }
}
