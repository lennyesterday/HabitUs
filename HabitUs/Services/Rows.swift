import Foundation
import HabitCore

// How rows look in the database (snake_case columns), and how they turn into HabitCore models.
// Only Services/ uses these. Area C.

/// Dates without time (`day`, `started_on`, `end_on`) are "yyyy-MM-dd" in Lisbon time.
enum DayFormat {
    static let lisbon = TimeZone(identifier: "Europe/Lisbon") ?? .current

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = lisbon
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(_ date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(_ string: String) -> Date? {
        formatter.date(from: string)
    }

    /// A date picked in the phone's calendar, as the same calendar day in Lisbon.
    static func lisbonDay(fromPicked date: Date) -> Date {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = lisbon
        return calendar.date(from: parts) ?? date
    }
}

struct GroupRow: Decodable {
    let id: UUID
    let name: String
    let habit: String
    let target: Int
    let periodDays: Int
    let endOn: String?
    let rulesText: String
    let inviteCode: String
    let ownerId: UUID
    let startedOn: String?
    let endedEarlyAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, habit, target
        case periodDays = "period_days"
        case endOn = "end_on"
        case rulesText = "rules_text"
        case inviteCode = "invite_code"
        case ownerId = "owner_id"
        case startedOn = "started_on"
        case endedEarlyAt = "ended_early_at"
    }

    var model: HabitGroup {
        HabitGroup(id: id, name: name, habit: habit, target: target,
                   period: Period(rawValue: periodDays) ?? .week,
                   endOn: endOn.flatMap(DayFormat.date), rulesText: rulesText, inviteCode: inviteCode,
                   ownerId: ownerId, startedOn: startedOn.flatMap(DayFormat.date), endedEarlyAt: endedEarlyAt)
    }
}

struct ProfileRow: Decodable {
    let displayName: String
    let avatar: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatar
    }
}

struct MemberRow: Decodable {
    let id: UUID
    let userId: UUID
    let status: String
    let signature: String
    let profiles: ProfileRow

    enum CodingKeys: String, CodingKey {
        case id, status, signature, profiles
        case userId = "user_id"
    }

    var model: Member {
        Member(id: id, userId: userId, displayName: profiles.displayName, avatar: profiles.avatar,
               status: MembershipStatus(rawValue: status) ?? .pending, signature: signature)
    }
}

struct ReactionRow: Decodable {
    let checkinId: UUID
    let userId: UUID
    let kind: String

    enum CodingKeys: String, CodingKey {
        case kind
        case checkinId = "checkin_id"
        case userId = "user_id"
    }

    var model: Reaction? {
        ReactionKind(rawValue: kind).map { Reaction(checkinId: checkinId, userId: userId, kind: $0) }
    }
}

struct CheckinRow: Decodable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let kind: String
    let photoPath: String?
    let text: String
    let day: String
    let createdAt: Date
    let reactions: [ReactionRow]

    enum CodingKeys: String, CodingKey {
        case id, kind, text, day, reactions
        case groupId = "group_id"
        case userId = "user_id"
        case photoPath = "photo_path"
        case createdAt = "created_at"
    }

    var model: Checkin {
        Checkin(id: id, groupId: groupId, userId: userId, kind: CheckinKind(rawValue: kind) ?? .photo,
                photoPath: photoPath, text: text, day: DayFormat.date(day) ?? createdAt, createdAt: createdAt)
    }
}

struct MessageRow: Decodable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let text: String
    let gifUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, text
        case groupId = "group_id"
        case userId = "user_id"
        case gifUrl = "gif_url"
        case createdAt = "created_at"
    }

    var model: Message {
        Message(id: id, groupId: groupId, userId: userId, text: text,
                gifURL: gifUrl.flatMap(URL.init(string:)), createdAt: createdAt)
    }
}
