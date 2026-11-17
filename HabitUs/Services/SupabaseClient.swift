import Foundation
import HabitCore
import Supabase

// The one connection to our Supabase project. Only files in Services/ use it. Area C.
// URL and anon key come from Config/Secrets.xcconfig through Config/Info.plist.

let supabase: SupabaseClient = {
    guard let urlText = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
          urlText.hasPrefix("https://"),
          let url = URL(string: urlText),
          let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
          !key.isEmpty else {
        fatalError("Supabase is not set up. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and fill in the URL and the anon key.")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: key)
}()

/// Thrown by service stubs that nobody has built yet.
let notBuiltYet = RuleError("This part is not built yet.")
