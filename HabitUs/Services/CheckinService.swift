import UIKit
import HabitCore
import Supabase

// Photo check-ins, pauses, like and X, and the feed (R12, R13, R15 to R19, R25). Area B.

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

    var createdAt: Date {
        switch self {
        case .message(let message): return message.createdAt
        case .checkin(let checkin, _): return checkin.createdAt
        }
    }
}

private struct NewCheckin: Encodable {
    let group_id: UUID
    let kind: String
    let photo_path: String?
    let text: String
}

enum CheckinService {
    /// R12, R13: checks the rules with HabitCore, uploads the photo, writes the check-in.
    /// The database sets the time and the day.
    static func addPhoto(groupId: UUID, image: UIImage, caption: String) async throws {
        let data = try await GroupService.load(groupId: groupId)
        let now = Date()
        let status = data.taskStatus(of: data.me, now: now)
        guard status.canCheckInToday else {
            if phase(of: data.group, now: now) != .active {
                throw RuleError("The session is not running.")
            } else if status.open == 0 {
                throw RuleError("All tasks of this round are done.")
            } else {
                throw RuleError("You already checked in today. Come back tomorrow.")
            }
        }
        let path = try await PhotoService.upload(image, groupId: groupId)
        try await readable {
            try await supabase.from("checkins")
                .insert(NewCheckin(group_id: groupId, kind: "photo", photo_path: path,
                                   text: String(caption.prefix(200))))
                .execute()
        }
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
        try await GroupService.load(groupId: groupId).feed(limit: limit)
    }
}
