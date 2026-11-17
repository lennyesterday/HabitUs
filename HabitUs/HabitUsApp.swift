import SwiftUI

@main
struct HabitUsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Nobody logged in: sign up and log in. Otherwise Home (SPEC section 4).
struct RootView: View {
    @State private var userId: UUID?
    @State private var checked = false

    var body: some View {
        if !Backend.isConfigured {
            SetupHintView()
        } else {
            content
                .task {
                    // Updates every time someone logs in or out. The session stays in the Keychain.
                    for await id in AuthService.userChanges() {
                        userId = id
                        checked = true
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !checked {
            ProgressView()
        } else if userId == nil {
            AuthView()
        } else {
            HomeView()
                .id(userId)
        }
    }
}

/// Shown when Config/Secrets.xcconfig is missing, instead of crashing.
struct SetupHintView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supabase is not set up")
                .font(.title2.bold())
            Text("Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig, fill in the project URL and the anon key, then build again.")
        }
        .padding()
    }
}
