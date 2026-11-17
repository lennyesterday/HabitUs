import Foundation
import HabitCore
import Supabase

// Sign up, log in, log out (R1 to R3). Area A.
// STUBS: replace each body with the real Supabase call.

enum AuthService {
    /// R1: checks the input with HabitCore, creates the account and the profile row.
    static func signUp(email: String, password: String, displayName: String, avatar: String) async throws {
        throw notBuiltYet
    }

    /// R3: the same error text for an unknown email and a wrong password.
    static func logIn(email: String, password: String) async throws {
        throw notBuiltYet
    }

    static func logOut() async throws {
        throw notBuiltYet
    }

    /// The id of the logged-in user, or nil. The session is kept in the Keychain (R2).
    static var currentUser: UUID? {
        nil
    }
}
