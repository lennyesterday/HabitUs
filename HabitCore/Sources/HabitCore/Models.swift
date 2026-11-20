import Foundation

// Plain data the rules work with. The services turn database rows into these.
// Area C owns this file. Changing a type here needs a message to the team.

/// Per what the habit is done: a round is 1, 7 or 28 days long (R9).
public enum Period: Int, Sendable, CaseIterable {
    case day = 1
    case week = 7
    case month = 28

    /// The most tasks one round may have (R4).
    public var maxTarget: Int {
        switch self {
        case .day: return 10
        case .week: return 7
        case .month: return 28
        }
    }
}

/// A group (table `groups`). Called `HabitGroup` because SwiftUI already has a `Group`.
public struct HabitGroup: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var habit: String
    public var icon: String          // one emoji, shown when there is no group picture
    public var photoPath: String?    // group picture in the "pictures" bucket
    public var target: Int
    public var period: Period
    public var endOn: Date?          // nil = open end
    public var rulesText: String
    public var inviteCode: String
    public var ownerId: UUID
    public var startedOn: Date?      // nil while in the lobby
    public var endedEarlyAt: Date?   // set when the owner presses Finish challenge

    public init(id: UUID, name: String, habit: String, icon: String, photoPath: String?, target: Int,
                period: Period, endOn: Date?, rulesText: String, inviteCode: String, ownerId: UUID,
                startedOn: Date?, endedEarlyAt: Date?) {
        self.id = id
        self.name = name
        self.habit = habit
        self.icon = icon
        self.photoPath = photoPath
        self.target = target
        self.period = period
        self.endOn = endOn
        self.rulesText = rulesText
        self.inviteCode = inviteCode
        self.ownerId = ownerId
        self.startedOn = startedOn
        self.endedEarlyAt = endedEarlyAt
    }
}

public enum MembershipStatus: String, Sendable {
    case pending, accepted, declined
}

/// A person in a group: their membership row plus name and profile picture from `profiles`.
public struct Member: Sendable, Equatable, Identifiable {
    public var id: UUID              // membership id
    public var userId: UUID
    public var displayName: String
    public var photoPath: String?    // profile picture in the "pictures" bucket
    public var status: MembershipStatus
    public var signature: String
    public var signedAt: Date?       // when the contract was signed (set by the database)
    /// The first round this member plays (R29). 1 for everyone who was there at the start,
    /// later for someone who joined a running challenge (set by the database when accepted).
    public var firstRound: Int

    public init(id: UUID, userId: UUID, displayName: String, photoPath: String?,
                status: MembershipStatus, signature: String, signedAt: Date? = nil, firstRound: Int = 1) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.photoPath = photoPath
        self.status = status
        self.signature = signature
        self.signedAt = signedAt
        self.firstRound = max(1, firstRound)
    }
}

public enum CheckinKind: String, Sendable {
    case photo, pause
}

/// A photo proof or a pause (table `checkins`).
public struct Checkin: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var groupId: UUID
    public var userId: UUID
    public var kind: CheckinKind
    public var photoPath: String?
    public var text: String          // caption or pause reason
    public var day: Date             // Lisbon day, set by the database
    public var createdAt: Date

    public init(id: UUID, groupId: UUID, userId: UUID, kind: CheckinKind, photoPath: String?,
                text: String, day: Date, createdAt: Date) {
        self.id = id
        self.groupId = groupId
        self.userId = userId
        self.kind = kind
        self.photoPath = photoPath
        self.text = text
        self.day = day
        self.createdAt = createdAt
    }
}

public enum ReactionKind: String, Sendable {
    case like, x
}

/// One like or X on a check-in (table `reactions`).
public struct Reaction: Sendable, Equatable {
    public var checkinId: UUID
    public var userId: UUID
    public var kind: ReactionKind

    public init(checkinId: UUID, userId: UUID, kind: ReactionKind) {
        self.checkinId = checkinId
        self.userId = userId
        self.kind = kind
    }
}

/// Where a group is right now. Computed, never stored (SPEC section 5).
public enum Phase: Sendable, Equatable {
    case lobby, active, ended
}

/// The tasks of one member in the current round (R10 to R12).
public struct TaskStatus: Sendable, Equatable {
    public var target: Int
    public var done: Int
    public var failed: Int           // rejected pauses
    public var open: Int
    public var canCheckInToday: Bool

    public init(target: Int, done: Int, failed: Int, open: Int, canCheckInToday: Bool) {
        self.target = target
        self.done = done
        self.failed = failed
        self.open = open
        self.canCheckInToday = canCheckInToday
    }
}

/// One line of the leaderboard (R24).
public struct LeaderboardRow: Sendable, Equatable, Identifiable {
    public var userId: UUID
    public var displayName: String
    public var photoPath: String?
    public var points: Int
    public var completeRounds: Int
    public var streak: Int
    public var pauses: Int
    /// Points of each round so far, for the chart on the leaderboard.
    public var pointsPerRound: [Int]
    /// Counted tasks of each round the member played, starting at `firstRound`,
    /// for the player profile and the grade.
    public var donePerRound: [Int]
    /// The first round the member played (R29). Rounds before it got the group average.
    public var firstRound: Int
    /// Points given for the rounds before `firstRound` (R29). Part of `points`.
    public var catchUpPoints: Int

    public var id: UUID { userId }

    public init(userId: UUID, displayName: String, photoPath: String?, points: Int,
                completeRounds: Int, streak: Int, pauses: Int, pointsPerRound: [Int] = [],
                donePerRound: [Int] = [], firstRound: Int = 1, catchUpPoints: Int = 0) {
        self.firstRound = firstRound
        self.catchUpPoints = catchUpPoints
        self.userId = userId
        self.displayName = displayName
        self.photoPath = photoPath
        self.points = points
        self.completeRounds = completeRounds
        self.streak = streak
        self.pauses = pauses
        self.pointsPerRound = pointsPerRound
        self.donePerRound = donePerRound
    }
}

/// A broken rule, with a text the view can show as it is.
public struct RuleError: Error, Equatable, LocalizedError {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

/// How well a member keeps the habit, from A (best) to D, for the player profile.
public enum Grade: String, Sendable, Equatable {
    case a = "A", b = "B", c = "C", d = "D"
}
