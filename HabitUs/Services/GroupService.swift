import UIKit
import HabitCore
import Supabase

// Create, join, accept, start and finish groups (R4 to R8). Area A.

/// One card on Home (SPEC section 4, Home).
struct GameCard: Identifiable {
    var group: HabitGroup
    var myStatus: MembershipStatus
    var isOwner: Bool
    var acceptedCount: Int
    var openRequests: Int

    var id: UUID { group.id }
}

/// The contract fields of a group. Shown before signing (create and join) and read only later.
struct Contract: Hashable {
    var name: String
    var habit: String
    var icon: String
    var target: Int
    var period: Period
    var endOn: Date?
    var rulesText: String

    init(name: String, habit: String, icon: String, target: Int, period: Period, endOn: Date?,
         rulesText: String) {
        self.name = name
        self.habit = habit
        self.icon = icon
        self.target = target
        self.period = period
        self.endOn = endOn
        self.rulesText = rulesText
    }

    init(_ group: HabitGroup) {
        self.init(name: group.name, habit: group.habit, icon: group.icon, target: group.target,
                  period: group.period, endOn: group.endOn, rulesText: group.rulesText)
    }
}

/// Everything the group screen needs, loaded in one go. All numbers on screen are computed
/// from this with HabitCore (points are never stored).
struct GroupData {
    var me: UUID
    var group: HabitGroup
    var members: [Member]
    var checkins: [Checkin]
    var reactions: [Reaction]
    var messages: [Message]

    var accepted: [Member] { members.filter { $0.status == .accepted } }
    var pending: [Member] { members.filter { $0.status == .pending } }
    var myMembership: Member? { members.first { $0.userId == me } }
    var isOwner: Bool { group.ownerId == me }

    func member(_ userId: UUID) -> Member? {
        members.first { $0.userId == userId }
    }

    func taskStatus(of user: UUID, now: Date) -> TaskStatus {
        HabitCore.taskStatus(user: user, group: group, checkins: checkins, reactions: reactions,
                             memberCount: accepted.count, now: now)
    }

    func leaderboard(now: Date) -> [LeaderboardRow] {
        HabitCore.leaderboard(group: group, members: members, checkins: checkins,
                              reactions: reactions, now: now)
    }

    func isValid(_ checkin: Checkin) -> Bool {
        HabitCore.isValid(checkin, reactions: reactions, memberCount: accepted.count)
    }

    /// R25: text messages and check-ins in time order, newest at the bottom, the last `limit` items.
    func feed(limit: Int = 50) -> [FeedItem] {
        let items = messages.map { FeedItem.message($0) }
            + checkins.map { checkin in
                FeedItem.checkin(checkin, reactions: reactions.filter { $0.checkinId == checkin.id })
            }
        return Array(items.sorted { $0.createdAt < $1.createdAt }.suffix(limit))
    }
}

// What the app sends when it creates rows. owner_id and user_id are filled in by the database.
private struct NewGroup: Encodable {
    let name: String
    let habit: String
    let icon: String
    let target: Int
    let period_days: Int
    let end_on: String?
    let rules_text: String
    let invite_code: String
}

private struct NewMembership: Encodable {
    let group_id: UUID
    let status: String
    let signature: String
}

private struct PreviewRow: Decodable {
    let name: String
    let habit: String
    let icon: String
    let target: Int
    let period_days: Int
    let end_on: String?
    let rules_text: String
}

/// Both columns are always sent, so removing the picture writes NULL.
private struct GroupLook: Encodable {
    let icon: String
    let photo_path: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(icon, forKey: .icon)
        try container.encode(photo_path, forKey: .photo_path)
    }

    enum CodingKeys: String, CodingKey {
        case icon, photo_path
    }
}

private struct MembershipStatusRow: Decodable {
    let group_id: UUID
    let status: String
}

private struct MyMembershipRow: Decodable {
    let status: String
    let groups: GroupRow
}

/// The hand-drawn signature is saved as text: "data:image/png;base64,...".
enum SignatureFormat {
    private static let prefix = "data:image/png;base64,"

    static func text(from png: Data) -> String {
        prefix + png.base64EncodedString()
    }

    /// The PNG behind a saved signature, or nil for old typed signatures.
    static func png(from text: String) -> Data? {
        guard text.hasPrefix(prefix) else { return nil }
        return Data(base64Encoded: String(text.dropFirst(prefix.count)))
    }
}

enum GroupService {
    /// R4: the creator becomes owner, signs the contract and gets an invite code.
    static func createGroup(name: String, habit: String, icon: String, target: Int, period: Period,
                            endOn: Date?, rulesText: String, signature: Data) async throws -> HabitGroup {
        try validateGroup(name: name, habit: habit, icon: icon, target: target, period: period,
                          endOn: endOn, today: localDay(Date()))
        try validateSignatureImage(signature)
        return try await readable {
            let new = NewGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                habit: habit.trimmingCharacters(in: .whitespaces),
                icon: icon,
                target: target,
                period_days: period.rawValue,
                end_on: endOn.map(DayFormat.string),
                rules_text: rulesText.trimmingCharacters(in: .whitespacesAndNewlines),
                invite_code: InviteCode.generate()
            )
            let row: GroupRow = try await supabase.from("groups")
                .insert(new)
                .select()
                .single()
                .execute()
                .value
            try await supabase.from("memberships")
                .insert(NewMembership(group_id: row.id, status: "accepted",
                                      signature: SignatureFormat.text(from: signature)))
                .execute()
            return row.model
        }
    }

    /// R5: the contract behind an invite code, so the joiner can read it before signing.
    static func previewContract(code: String) async throws -> Contract {
        let code = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count == 6 else {
            throw RuleError("An invite code has 6 characters.")
        }
        return try await readable {
            let rows: [PreviewRow] = try await supabase
                .rpc("preview_group_by_code", params: ["code": code])
                .execute()
                .value
            guard let row = rows.first else {
                throw RuleError("This invite code is not valid, or the game has already started.")
            }
            return Contract(name: row.name, habit: row.habit, icon: row.icon, target: row.target,
                            period: Period(rawValue: row.period_days) ?? .week,
                            endOn: row.end_on.flatMap(DayFormat.date), rulesText: row.rules_text)
        }
    }

    /// R5: calls the database function join_by_code, which creates a pending request.
    static func requestToJoin(code: String, signature: Data) async throws {
        try validateSignatureImage(signature)
        try await readable {
            try await supabase
                .rpc("join_by_code", params: [
                    "code": code.trimmingCharacters(in: .whitespaces).uppercased(),
                    "signature": SignatureFormat.text(from: signature),
                ])
                .execute()
        }
    }

    /// R6: owner only (checked by RLS). Only open requests change, so declined stays final.
    static func decide(membershipId: UUID, accept: Bool) async throws {
        try await readable {
            try await supabase.from("memberships")
                .update(["status": accept ? "accepted" : "declined"])
                .eq("id", value: membershipId)
                .eq("status", value: "pending")
                .execute()
        }
    }

    /// R7: owner only, at least 3 accepted members, one full round must fit.
    /// Sets the start day to today and declines all open requests.
    static func start(groupId: UUID) async throws {
        let data = try await load(groupId: groupId)
        let today = localDay(Date())
        guard data.isOwner else {
            throw RuleError("Only the owner can start the session.")
        }
        guard data.accepted.count >= 3 else {
            throw RuleError("You need at least 3 members including you to start.")
        }
        guard canStart(data.group, today: today) else {
            throw RuleError("The end date is too close. Not even one full round fits.")
        }
        try await readable {
            try await supabase.from("groups")
                .update(["started_on": DayFormat.string(today)])
                .eq("id", value: groupId)
                .execute()
            try await supabase.from("memberships")
                .update(["status": "declined"])
                .eq("group_id", value: groupId)
                .eq("status", value: "pending")
                .execute()
        }
    }

    /// R8: owner only, sets ended_early_at to now.
    static func finish(groupId: UUID) async throws {
        try await readable {
            try await supabase.from("groups")
                .update(["ended_early_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: groupId)
                .execute()
        }
    }

    /// Leave a group at any time. Also withdraws a pending request or removes a declined one.
    /// If the owner leaves, the member who joined first becomes owner. If nobody is left,
    /// the database deletes the group, so its photos are deleted here first.
    static func leave(groupId: UUID) async throws {
        let data = try await load(groupId: groupId)
        let othersLeft = data.accepted.contains { $0.userId != data.me }
        if data.isOwner && !othersLeft {
            try await PhotoService.deleteAll(groupId: groupId)
            await PictureService.deleteAll(groupId: groupId)
        }
        try await readable {
            try await supabase.rpc("leave_group", params: ["gid": groupId]).execute()
        }
    }

    /// Owner only: deletes the group for everyone, with all photos, check-ins and messages.
    static func delete(groupId: UUID) async throws {
        let data = try await load(groupId: groupId)
        guard data.isOwner else {
            throw RuleError("Only the owner can delete the group.")
        }
        try await PhotoService.deleteAll(groupId: groupId)
        await PictureService.deleteAll(groupId: groupId)
        try await readable {
            try await supabase.from("groups").delete().eq("id", value: groupId).execute()
        }
    }

    /// Owner only (RLS): change the group icon and picture. A picture replaces the icon on screen.
    /// `picture` nil keeps the current picture, `removePicture` deletes it.
    static func updateLook(of group: HabitGroup, icon: String, picture: UIImage?,
                           removePicture: Bool) async throws {
        try validateGroupIcon(icon)
        var path = removePicture ? nil : group.photoPath
        if let picture {
            path = try await PictureService.upload(picture, folder: "groups/\(group.id.uuidString.lowercased())")
        }
        let newPath = path
        try await readable {
            try await supabase.from("groups")
                .update(GroupLook(icon: icon, photo_path: newPath))
                .eq("id", value: group.id)
                .execute()
        }
        if group.photoPath != path {
            await PictureService.deleteQuietly(path: group.photoPath)
        }
    }

    /// All games I created or asked to join, newest first.
    static func myGames() async throws -> [GameCard] {
        let me = try requireUser()
        return try await readable {
            let mine: [MyMembershipRow] = try await supabase.from("memberships")
                .select("status, groups(*)")
                .eq("user_id", value: me)
                .order("signed_at", ascending: false)
                .execute()
                .value
            let ids = mine.map(\.groups.id)
            // RLS only shows the other members of groups where I am accepted.
            let all: [MembershipStatusRow] = ids.isEmpty ? [] : try await supabase.from("memberships")
                .select("group_id, status")
                .in("group_id", values: ids)
                .execute()
                .value
            return mine.map { row in
                let group = row.groups.model
                let ofGroup = all.filter { $0.group_id == group.id }
                return GameCard(group: group,
                                myStatus: MembershipStatus(rawValue: row.status) ?? .pending,
                                isOwner: group.ownerId == me,
                                acceptedCount: ofGroup.filter { $0.status == "accepted" }.count,
                                openRequests: ofGroup.filter { $0.status == "pending" }.count)
            }
        }
    }

    static func members(groupId: UUID) async throws -> [Member] {
        try await readable {
            let rows: [MemberRow] = try await supabase.from("memberships")
                .select("id, user_id, status, signature, profiles(display_name, photo_path)")
                .eq("group_id", value: groupId)
                .order("signed_at")
                .execute()
                .value
            return rows.map(\.model)
        }
    }

    /// Group, members, all check-ins with their reactions and the last 50 messages.
    /// A pending member only gets the group and their own membership (RLS, R27).
    static func load(groupId: UUID) async throws -> GroupData {
        let me = try requireUser()
        return try await readable {
            let groupRow: GroupRow = try await supabase.from("groups")
                .select()
                .eq("id", value: groupId)
                .single()
                .execute()
                .value
            let members = try await members(groupId: groupId)
            let checkinRows: [CheckinRow] = try await supabase.from("checkins")
                .select("*, reactions(*)")
                .eq("group_id", value: groupId)
                .order("created_at")
                .execute()
                .value
            let messageRows: [MessageRow] = try await supabase.from("messages")
                .select()
                .eq("group_id", value: groupId)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            return GroupData(me: me,
                             group: groupRow.model,
                             members: members,
                             checkins: checkinRows.map(\.model),
                             reactions: checkinRows.flatMap { $0.reactions.compactMap(\.model) },
                             messages: messageRows.reversed().map(\.model))
        }
    }
}
