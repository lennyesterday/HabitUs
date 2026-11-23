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

private struct NewReaction: Encodable {
    let checkin_id: UUID
    let user_id: UUID
    let kind: String
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

    /// R18: a pause with a reason of 1 to 200 characters. It counts as a done task until more
    /// than half of the others reject it within 48 hours. Not limited to one per day.
    static func addPause(groupId: UUID, reason: String) async throws {
        try validatePauseReason(reason)
        let data = try await GroupService.load(groupId: groupId)
        guard data.canPause(now: Date()) else {
            throw RuleError("You cannot take a pause right now.")
        }
        try await readable {
            try await supabase.from("checkins")
                .insert(NewCheckin(group_id: groupId, kind: "pause", photo_path: nil,
                                   text: reason.trimmingCharacters(in: .whitespacesAndNewlines)))
                .execute()
        }
    }

    /// R15: `.like`, `.x`, or nil to remove my reaction. HabitCore decides if a reaction is
    /// still allowed (not my own, still valid, round running). One row per person and check-in,
    /// so a second tap replaces the first one (upsert).
    static func setReaction(groupId: UUID, checkinId: UUID, kind: ReactionKind?) async throws {
        let data = try await GroupService.load(groupId: groupId)
        guard let checkin = data.checkins.first(where: { $0.id == checkinId }) else {
            throw RuleError("This proof no longer exists.")
        }
        guard data.canReact(to: checkin, now: Date()) else {
            throw RuleError("Voting on this proof is closed.")
        }
        try await readable {
            if let kind {
                try await supabase.from("reactions")
                    .upsert(NewReaction(checkin_id: checkinId, user_id: data.me, kind: kind.rawValue),
                            onConflict: "checkin_id,user_id")
                    .execute()
            } else {
                try await supabase.from("reactions")
                    .delete()
                    .eq("checkin_id", value: checkinId)
                    .eq("user_id", value: data.me)
                    .execute()
            }
        }
    }

    /// R25: the last `limit` items, oldest first.
    static func feed(groupId: UUID, limit: Int = 50) async throws -> [FeedItem] {
        try await GroupService.load(groupId: groupId).feed(limit: limit)
    }
}
