import Foundation

// Input checks for every form. Each one throws a RuleError with a readable text. Area A.

private func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// R1: email, password of at least 8 characters, name of 2 to 20 characters, terms ticked.
public func validateSignUp(email: String, password: String, displayName: String,
                           acceptedTerms: Bool) throws {
    try validateEmail(email)
    try validatePassword(password)
    guard (2...20).contains(trimmed(displayName).count) else {
        throw RuleError("Your name needs 2 to 20 characters.")
    }
    guard acceptedTerms else {
        throw RuleError("Please accept the terms.")
    }
}

/// R1: one "@", something before it and a domain with a dot after it.
public func validateEmail(_ email: String) throws {
    let parts = trimmed(email).split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."), !parts[1].hasSuffix(".") else {
        throw RuleError("Please enter a valid email address.")
    }
}

/// R1: at least 8 characters. Used for sign up and for a new password after "Forgot password?".
public func validatePassword(_ password: String) throws {
    guard password.count >= 8 else {
        throw RuleError("The password needs at least 8 characters.")
    }
}

/// R4: name (1 to 40), habit (1 to 20), one emoji as icon, how often (1 up to `period.maxTarget`),
/// and an end date that leaves room for at least one full round from today.
public func validateGroup(name: String, habit: String, icon: String, target: Int, period: Period,
                          endOn: Date?, today: Date) throws {
    guard (1...40).contains(trimmed(name).count) else {
        throw RuleError("The group name needs 1 to 40 characters.")
    }
    guard (1...20).contains(trimmed(habit).count) else {
        throw RuleError("The habit needs 1 to 20 characters, for example \"Gym\".")
    }
    try validateGroupIcon(icon)
    guard (1...period.maxTarget).contains(target) else {
        throw RuleError("How often must be between 1 and \(period.maxTarget).")
    }
    if let endOn, daysBetween(today, endOn) + 1 < period.rawValue {
        throw RuleError("The end date is too early. At least one full round has to fit.")
    }
}

/// R4: the group icon is exactly one emoji, also emojis made of several parts (👩‍👩‍👧, 🇵🇹, 🏋️).
/// Digits and # count as "emoji" in Unicode, so they only pass with the emoji style marker.
public func validateGroupIcon(_ icon: String) throws {
    guard icon.count == 1, let character = icon.first else {
        throw RuleError("Please pick one emoji as the group icon.")
    }
    let scalars = character.unicodeScalars
    let emojiStyle = scalars.contains { $0.value == 0xFE0F }
    guard scalars.contains(where: { $0.properties.isEmojiPresentation })
            || (emojiStyle && scalars.contains { $0.properties.isEmoji }) else {
        throw RuleError("Please pick one emoji as the group icon.")
    }
}

/// R4, R5: the signature under the contract, drawn by hand and saved as a PNG of at most 40 KB.
public func validateSignatureImage(_ png: Data) throws {
    let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    guard !png.isEmpty else {
        throw RuleError("Please sign the contract with your finger.")
    }
    guard png.starts(with: pngHeader), png.count < 40_000 else {
        throw RuleError("The signature could not be saved. Please clear it and sign again.")
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

/// R1 (with email confirmation): the code from the email is 6 to 10 digits.
/// Spaces from copy and paste are removed. Returns the cleaned code to send to the server.
@discardableResult
public func validateEmailCode(_ code: String) throws -> String {
    let digits = code.filter { !$0.isWhitespace }
    guard (6...10).contains(digits.count), digits.allSatisfy({ $0.isASCII && $0.isNumber }) else {
        throw RuleError("Please enter the code from the email (6 digits).")
    }
    return digits
}
