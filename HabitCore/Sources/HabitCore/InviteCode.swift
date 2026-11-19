import Foundation

// Invite codes (R4, S9). Area A.

public enum InviteCode {
    /// Letters and digits without 0, O, 1 and I, so nobody mixes them up.
    public static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    /// A new 6 character code from `SystemRandomNumberGenerator`.
    public static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        let characters = (0..<6).map { _ in
            alphabet[Int.random(in: 0..<alphabet.count, using: &generator)]
        }
        return String(characters)
    }
}
