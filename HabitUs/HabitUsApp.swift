import SwiftUI

@main
struct HabitUsApp: App {
    var body: some Scene {
        WindowGroup {
            // Nobody logged in: sign up and log in. Otherwise Home (SPEC section 4).
            if AuthService.currentUser == nil {
                AuthView()
            } else {
                HomeView()
            }
        }
    }
}
