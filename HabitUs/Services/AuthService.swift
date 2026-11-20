import UIKit
import HabitCore
import Supabase

// Sign up, log in, log out (R1 to R3). Area A.
// Passwords go only to Supabase Auth, which stores a bcrypt hash (R2, S1).

/// Name and profile picture of the logged-in user, for "Hi Lenny 👋".
struct Profile {
    var displayName: String
    var photoPath: String?
}

private struct NewProfile: Encodable {
    let id: UUID
    let display_name: String
    let avatar: String
}

/// Thrown by `logIn` when the password was right, but the email address was never confirmed.
/// A new code has been sent, so the view can ask for it.
struct EmailNotConfirmed: Error {}

enum AuthService {
    /// R1: checks the input with HabitCore, then creates the account. The database trigger
    /// from 002_profiles_and_join_preview.sql creates the profile row from the name.
    /// Returns true if Supabase sent a confirmation code that has to be entered next
    /// ("Confirm email" turned on). Returns false if the person is logged in right away.
    @discardableResult
    static func signUp(email: String, password: String, displayName: String,
                       acceptedTerms: Bool) async throws -> Bool {
        try validateSignUp(email: email, password: password, displayName: displayName,
                           acceptedTerms: acceptedTerms)
        return try await readable {
            let response = try await supabase.auth.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                data: ["display_name": .string(displayName.trimmingCharacters(in: .whitespaces))]
            )
            // No session means: Supabase emailed a code and waits for it.
            return response.session == nil
        }
    }

    /// Checks the code from the confirmation email. On success Supabase logs the person in,
    /// and RootView switches to Home by itself.
    static func verifyEmailCode(email: String, code: String) async throws {
        let cleanCode = try validateEmailCode(code)
        do {
            try await supabase.auth.verifyOTP(email: email.trimmingCharacters(in: .whitespaces),
                                              token: cleanCode, type: .signup)
        } catch is URLError {
            throw RuleError("No connection to the server. Please check your internet and try again.")
        } catch {
            throw RuleError("This code is wrong or expired. Ask for a new one.")
        }
    }

    /// Sends a new confirmation code to the email address.
    static func resendEmailCode(email: String) async throws {
        try await readable {
            try await supabase.auth.resend(email: email.trimmingCharacters(in: .whitespaces), type: .signup)
        }
    }

    /// "Forgot password?": Supabase emails a reset code. It says nothing about whether an
    /// account with this email exists, so nobody can find out who uses the app (like R3).
    static func sendResetCode(email: String) async throws {
        try validateEmail(email)
        try await readable {
            try await supabase.auth.resetPasswordForEmail(email.trimmingCharacters(in: .whitespaces))
        }
    }

    /// Checks the reset code, which logs the person in, then sets the new password.
    /// Both inputs are checked first, so a short password does not use up the code.
    /// Once the code is right, RootView switches to Home by itself.
    static func setNewPassword(email: String, code: String, password: String) async throws {
        let cleanCode = try validateEmailCode(code)
        try validatePassword(password)
        do {
            try await supabase.auth.verifyOTP(email: email.trimmingCharacters(in: .whitespaces),
                                              token: cleanCode, type: .recovery)
        } catch is URLError {
            throw RuleError("No connection to the server. Please check your internet and try again.")
        } catch {
            throw RuleError("This code is wrong or expired. Ask for a new one.")
        }
        try await readable {
            _ = try await supabase.auth.update(user: UserAttributes(password: password))
        }
    }

    /// R3: the same error text for an unknown email and a wrong password.
    static func logIn(email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespaces)
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch is URLError {
            throw RuleError("No connection to the server. Please check your internet and try again.")
        } catch let error as AuthError where error.errorCode == .emailNotConfirmed {
            // Supabase only says this when the password was right, so R3 still holds.
            try? await supabase.auth.resend(email: email, type: .signup)
            throw EmailNotConfirmed()
        } catch {
            throw RuleError("Email or password is wrong.")
        }
    }

    static func logOut() async throws {
        try await readable {
            try await supabase.auth.signOut()
        }
    }

    /// The id of the logged-in user, or nil. The session is kept in the Keychain (R2).
    static var currentUser: UUID? {
        supabase.auth.currentUser?.id
    }

    /// Sends the logged-in user id (or nil) now and every time someone logs in or out.
    static func userChanges() -> AsyncStream<UUID?> {
        AsyncStream { continuation in
            let task = Task {
                for await change in supabase.auth.authStateChanges {
                    continuation.yield(change.session?.user.id)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func myProfile() async throws -> Profile {
        let me = try requireUser()
        return try await readable {
            let rows: [ProfileRow] = try await supabase.from("profiles")
                .select("display_name, photo_path")
                .eq("id", value: me)
                .limit(1)
                .execute()
                .value
            if let row = rows.first {
                return Profile(displayName: row.displayName, photoPath: row.photoPath)
            }
            return try await createMissingProfile(for: me)
        }
    }

    /// Accounts made before the sign up trigger existed (002) have no profile row.
    /// Creates it with the name from sign up, so the account works normally (RLS allows only your own row).
    private static func createMissingProfile(for me: UUID) async throws -> Profile {
        var name = "Player"
        if case .string(let text)? = supabase.auth.currentUser?.userMetadata["display_name"],
           (2...20).contains(text.trimmingCharacters(in: .whitespaces).count) {
            name = text.trimmingCharacters(in: .whitespaces)
        }
        do {
            try await supabase.from("profiles")
                .insert(NewProfile(id: me, display_name: name, avatar: "🙂"))
                .execute()
        } catch let error as PostgrestError where error.code == "23503" {
            // 23503 = the account itself is gone (for example deleted in the dashboard),
            // only the old login is left on this phone. Log out, so the person can sign up again.
            try? await supabase.auth.signOut()
            throw RuleError("This account does not exist any more. Please sign up again.")
        }
        return Profile(displayName: name, photoPath: nil)
    }

    /// Sets a new profile picture (or removes it with nil) and deletes the old one.
    static func setProfilePicture(_ image: UIImage?) async throws -> Profile {
        let me = try requireUser()
        let old = try await myProfile()
        var path: String?
        if let image {
            path = try await PictureService.upload(image, folder: "users/\(me.uuidString.lowercased())")
        }
        let newPath = path
        try await readable {
            try await supabase.from("profiles")
                .update(["photo_path": newPath])
                .eq("id", value: me)
                .execute()
        }
        await PictureService.deleteQuietly(path: old.photoPath)
        return Profile(displayName: old.displayName, photoPath: path)
    }
}
