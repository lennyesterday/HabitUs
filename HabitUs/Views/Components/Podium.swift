import SwiftUI
import HabitCore

// Top 3 of the leaderboard with a crown on the leader, and colored rows for everybody. Area C.

struct Podium: View {
    let rows: [LeaderboardRow]

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom, spacing: 18) {
                place(1)
                place(0)
                place(2)
            }
            if let best = rows.first, best.points > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "laurel.leading")
                    VStack(spacing: 0) {
                        Text("Best player")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        Text(best.displayName.uppercased())
                            .font(Theme.title(28))
                        Text("\(best.points) pts")
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                    }
                    Image(systemName: "laurel.trailing")
                }
                .font(.system(size: 44))
                .foregroundStyle(Theme.ink)
            }
        }
    }

    @ViewBuilder
    private func place(_ index: Int) -> some View {
        if rows.indices.contains(index) {
            let row = rows[index]
            let leader = index == 0
            VStack(spacing: -6) {
                if leader {
                    Text("👑").font(.system(size: 34)).zIndex(1)
                }
                ProfilePicture(name: row.displayName, path: row.photoPath, size: leader ? 84 : 64)
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
                    .opacity(leader ? 1 : 0.85)
                Pill(text: "\(row.points) pts", dark: false)
            }
        }
    }
}

/// One colored row per player: place, picture, points, name and streak.
struct RankingRows: View {
    let rows: [LeaderboardRow]
    let me: UUID

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let color = Theme.rankColor(index)
                HStack(spacing: 12) {
                    Text("#\(index + 1)")
                        .font(Theme.title(22))
                        .foregroundStyle(.white)
                        .frame(width: 46)
                    ProfilePicture(name: row.displayName, path: row.photoPath, size: 54)
                        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 3))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(row.points) pts")
                            .font(Theme.title(24))
                        Text(row.userId == me ? "\(row.displayName) (you)" : row.displayName)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    if row.streak > 0 {
                        Pill(text: "\(row.streak)", emoji: "🔥")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .ledgeCard(color, radius: 24, depth: 5)
            }
        }
    }
}
