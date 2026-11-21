import Foundation
@testable import HabitCore

// Small builders so every test can describe its situation in one or two lines.

let lisbon: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
    return calendar
}()

/// Midnight of that calendar day in Lisbon, like the `day` column in the database.
func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    lisbon.date(from: DateComponents(year: year, month: month, day: day))!
}

/// A moment in Lisbon time.
func time(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    lisbon.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func addDays(_ days: Int, to date: Date) -> Date {
    lisbon.date(byAdding: .day, value: days, to: date)!
}

let owner = UUID()
let alice = UUID()
let bob = UUID()
let carol = UUID()

func makeGroup(target: Int = 3, period: Period = .week, startedOn: Date? = day(2026, 1, 5),
               endOn: Date? = nil, endedEarlyAt: Date? = nil) -> HabitGroup {
    HabitGroup(id: UUID(), name: "Gym Crew", habit: "Gym", icon: "🏋️", photoPath: nil, target: target,
               period: period, endOn: endOn, rulesText: "", inviteCode: "ABC234", ownerId: owner,
               startedOn: startedOn, endedEarlyAt: endedEarlyAt)
}

func makeCheckin(_ user: UUID, on date: Date, kind: CheckinKind = .photo) -> Checkin {
    Checkin(id: UUID(), groupId: UUID(), userId: user, kind: kind,
            photoPath: kind == .photo ? "g/p.jpg" : nil, text: "",
            day: date, createdAt: date)
}

func makeMember(_ user: UUID, _ name: String, status: MembershipStatus = .accepted,
                firstRound: Int = 1) -> Member {
    Member(id: UUID(), userId: user, displayName: name, photoPath: nil, status: status, signature: name,
           firstRound: firstRound)
}

func xs(on checkin: Checkin, by users: [UUID]) -> [Reaction] {
    users.map { Reaction(checkinId: checkin.id, userId: $0, kind: .x) }
}
