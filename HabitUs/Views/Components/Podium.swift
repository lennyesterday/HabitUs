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
        }
    }

    @ViewBuilder
    private func place(_ index: Int) -> some View {
        if rows.indices.contains(index) {
            let row = rows[index]
            let leader = index == 0
            VStack(spacing: -6) {
                if leader {
                    Text("👑").font(.system(size: 26)).zIndex(1)
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

/// One white row per player with a colored place badge: place, picture, name, points and streak.
struct RankingRows: View {
    let rows: [LeaderboardRow]
    let me: UUID

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let color = Theme.rankColor(index)
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(color, in: Circle())
                    ProfilePicture(name: row.displayName, path: row.photoPath, size: 44)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.userId == me ? "\(row.displayName) (you)" : row.displayName)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                        Text("\(row.points) pts")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Theme.ink)
                    Spacer()
                    if row.streak > 0 {
                        Text("🔥 \(row.streak)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            }
        }
    }
}
