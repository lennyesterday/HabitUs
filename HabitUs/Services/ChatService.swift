import Foundation
import HabitCore
import Supabase

// Text messages in the group chat (R26). Area B.
// STUBS: replace each body with the real Supabase call.

/// A text message (table `messages`).
struct Message: Identifiable {
    var id: UUID
    var groupId: UUID
    var userId: UUID
    var text: String
    var createdAt: Date
}

enum ChatService {
    /// R26: 1 to 500 characters, checked with HabitCore before sending.
    static func post(groupId: UUID, text: String) async throws {
        throw notBuiltYet
    }
}
