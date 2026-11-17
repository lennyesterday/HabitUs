import UIKit
import HabitCore
import Supabase

// Photo check-ins, pauses, like and X, and the feed (R12, R13, R15 to R19, R25). Area B.
// STUBS: replace each body with the real Supabase call.

/// One entry in the group chat: a text message or a check-in with its reactions (R25).
enum FeedItem: Identifiable {
    case message(Message)
    case checkin(Checkin, reactions: [Reaction])

    var id: UUID {
        switch self {
        case .message(let message): return message.id
        case .checkin(let checkin, _): return checkin.id
        }
    }
}

enum CheckinService {
    /// R12, R13: checks the rules with HabitCore, uploads the photo, writes the check-in.
    static func addPhoto(groupId: UUID, image: UIImage, caption: String) async throws {
        throw notBuiltYet
    }

    /// R18: a pause with a reason of up to 200 characters.
    static func addPause(groupId: UUID, reason: String) async throws {
        throw notBuiltYet
    }

    /// R15: `.like`, `.x`, or nil to remove my reaction.
    static func setReaction(checkinId: UUID, kind: ReactionKind?) async throws {
        throw notBuiltYet
    }

    /// R25: the last `limit` items, oldest first.
    static func feed(groupId: UUID, limit: Int = 50) async throws -> [FeedItem] {
        throw notBuiltYet
    }
}
