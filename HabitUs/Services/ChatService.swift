import Foundation
import HabitCore
import Supabase

// Text messages in the group chat (R26). Area B.

/// A text message (table `messages`).
struct Message: Identifiable {
    var id: UUID
    var groupId: UUID
    var userId: UUID
    var text: String
    var gifURL: URL?
    var createdAt: Date
}

private struct NewMessage: Encodable {
    let group_id: UUID
    let text: String
    var gif_url: String? = nil
}

enum ChatService {
    /// R26: 1 to 500 characters, checked with HabitCore before sending.
    static func post(groupId: UUID, text: String) async throws {
        try validateMessage(text)
        try await readable {
            try await supabase.from("messages")
                .insert(NewMessage(group_id: groupId, text: text.trimmingCharacters(in: .whitespacesAndNewlines)))
                .execute()
        }
    }

    /// R26: a GIF from GIPHY, checked with HabitCore before sending.
    static func postGif(groupId: UUID, gif: Gif) async throws {
        try validateGifURL(gif.url.absoluteString)
        try await readable {
            try await supabase.from("messages")
                .insert(NewMessage(group_id: groupId, text: "", gif_url: gif.url.absoluteString))
                .execute()
        }
    }
}
