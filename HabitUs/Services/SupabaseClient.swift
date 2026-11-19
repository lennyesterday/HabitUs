import Foundation
import HabitCore
import Supabase

// The one connection to our Supabase project. Only files in Services/ use it. Area C.
// URL and anon key come from Config/Secrets.xcconfig through Config/Info.plist.

enum Backend {
    static var url: URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              text.hasPrefix("https://"), !text.contains("DEIN-PROJEKT") else { return nil }
        return URL(string: text)
    }

    static var anonKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty, key != "DEIN_ANON_KEY" else { return nil }
        return key
    }

    /// False until Config/Secrets.xcconfig is filled in. The app then shows a setup hint.
    static var isConfigured: Bool { url != nil && anonKey != nil }
}

let supabase: SupabaseClient = {
    guard let url = Backend.url, let key = Backend.anonKey else {
        fatalError("Supabase is not set up. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and fill in the URL and the anon key.")
    }
    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: key,
        options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
    )
}()

/// Thrown by service functions that nobody has built yet.
let notBuiltYet = RuleError("This part is not built yet.")

/// Runs a Supabase call and turns every error into a RuleError with a text the view can show.
@discardableResult
func readable<T>(_ work: () async throws -> T) async throws -> T {
    do {
        return try await work()
    } catch let error as RuleError {
        throw error
    } catch is URLError {
        throw RuleError("No connection to the server. Please check your internet and try again.")
    } catch let error as PostgrestError {
        throw RuleError(error.message)
    } catch {
        throw RuleError(error.localizedDescription)
    }
}

/// The id of the logged-in user, or an error if nobody is logged in.
func requireUser() throws -> UUID {
    guard let id = AuthService.currentUser else {
        throw RuleError("Please log in again.")
    }
    return id
}
