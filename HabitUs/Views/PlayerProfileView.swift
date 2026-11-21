import SwiftUI
import HabitCore

// One member of a group: stats, grade A to D, and the history round by round with the photos,
// pauses and missed tasks. Opened by tapping a row under the podium. Area C.
// Everything is computed from GroupData with HabitCore. Nothing new is stored.

struct PlayerProfileView: View {
    let data: GroupData
    let userId: UUID

    var body: some View {
        let now = Date()
        let rows = data.leaderboard(now: now)
        let index = rows.firstIndex { $0.userId == userId }
        let row = index.map { rows[$0] }
        let member = data.member(userId)
        let running = phase(of: data.group, now: now) == .active
        // The current round is still running, so only finished rounds count for the grade.
        let finished = running ? Array((row?.donePerRound ?? []).dropLast()) : (row?.donePerRound ?? [])
        let playerGrade = grade(donePerRound: finished, target: data.group.target)

        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    ProfilePicture(name: member?.displayName ?? "?", path: member?.photoPath, size: 96)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    Text(member?.displayName ?? "Former member")
                        .font(Theme.title(28))
                        .foregroundStyle(Theme.ink)
                    if let index {
                        Text("#\(index + 1) of \(rows.count) in \(data.group.name)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                gradeCard(playerGrade, finishedRounds: finished.count)

                if let row {
                    statsGrid(row)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("History")
                        .font(Theme.title(22))
                        .foregroundStyle(Theme.ink)
                    if let row, !row.donePerRound.isEmpty {
                        // R29: someone who joined later has their own rounds from firstRound on.
                        let lastPlayed = row.firstRound + row.donePerRound.count - 1
                        ForEach((row.firstRound...lastPlayed).reversed(), id: \.self) { round in
                            roundCard(round: round, row: row, isRunning: running && round == lastPlayed)
                        }
                    } else {
                        Text("No rounds yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let row, row.firstRound > 1 {
                    Label("Joined in round \(row.firstRound). Rounds 1 to \(row.firstRound - 1) got the group average: \(row.catchUpPoints) pts.",
                          systemImage: "person.badge.plus")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
        }
        .background(PaperBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Grade

    private func gradeCard(_ playerGrade: Grade?, finishedRounds: Int) -> some View {
        let (color, text) = describe(playerGrade)
        return HStack(spacing: 16) {
            Text(playerGrade?.rawValue ?? "–")
                .font(Theme.title(40))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(color, in: RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(playerGrade == nil
                     ? "The grade appears after the first finished round."
                     : "Share of tasks done in \(finishedRounds) finished round\(finishedRounds == 1 ? "" : "s"). A from 90 %, B from 70 %, C from 50 %.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private func describe(_ playerGrade: Grade?) -> (Color, String) {
        switch playerGrade {
        case .a: return (Theme.rankColor(1), "Keeps the habit 💪")
        case .b: return (Theme.rankColor(3), "Mostly there")
        case .c: return (Theme.rankColor(4), "Slipping a bit")
        case .d: return (Theme.rankColor(0), "Needs a push")
        case nil: return (Color(white: 0.7), "Too early to tell")
        }
    }

    // MARK: - Stats

    private func statsGrid(_ row: LeaderboardRow) -> some View {
        HStack(spacing: 10) {
            stat("\(row.points)", "points")
            stat("🔥 \(row.streak)", "streak")
            stat("\(row.completeRounds)", "full rounds")
            stat("\(row.pauses)", "pauses")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - History

    private func roundCard(round: Int, row: LeaderboardRow, isRunning: Bool) -> some View {
        let target = data.group.target
        let done = row.donePerRound[round - row.firstRound]
        let points = row.pointsPerRound.indices.contains(round - 1) ? row.pointsPerRound[round - 1] : 0
        let checkins = data.checkins
            .filter { $0.userId == userId && HabitCore.round(of: $0.day, in: data.group) == round }
            .sorted { $0.createdAt < $1.createdAt }
        let pauses = checkins.filter { $0.kind == .pause }
        let photos = checkins.filter { $0.kind == .photo }
        let missed = isRunning ? 0 : max(0, target - done)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isRunning ? "Round \(round) · now" : "Round \(round)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer()
                Text("\(done)/\(target) done · \(points) pts")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(done >= target ? Theme.rankColor(1) : .secondary)
            }
            .foregroundStyle(Theme.ink)

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            ProofThumbnail(checkin: photo, valid: data.isValid(photo))
                        }
                    }
                }
            }

            ForEach(pauses) { pause in
                Label("Paused: \(pause.text)\(data.isValid(pause) ? "" : " (rejected)")",
                      systemImage: "pause.circle.fill")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(data.isValid(pause) ? Color.secondary : Theme.rankColor(0))
            }

            if missed > 0 {
                Label("\(missed) task\(missed == 1 ? "" : "s") missed", systemImage: "xmark.circle.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.rankColor(0))
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

/// A small square photo with the day and a mark if the group rejected it.
private struct ProofThumbnail: View {
    let checkin: Checkin
    let valid: Bool

    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Theme.cardBackground).overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .opacity(valid ? 1 : 0.45)

                if !valid {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, Theme.rankColor(0))
                        .padding(4)
                }
            }
            Text(checkin.createdAt.formatted(.dateTime.weekday(.abbreviated).day()))
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .task(id: checkin.photoPath) {
            if let path = checkin.photoPath {
                image = try? await PhotoService.load(path: path)
            }
        }
    }
}

#Preview {
    let data = GroupData.preview
    let other = data.accepted.first { $0.userId != data.me }?.userId ?? data.me
    return NavigationStack {
        PlayerProfileView(data: data, userId: other)
    }
}
