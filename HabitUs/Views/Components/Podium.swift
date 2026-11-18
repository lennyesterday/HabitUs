import SwiftUI
import HabitCore

// Top 3 of the leaderboard: 🥈 left, 👑 middle, 🥉 right. Area C.

struct Podium: View {
    let rows: [LeaderboardRow]

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            place(1, medal: "🥈")
            place(0, medal: "👑")
            place(2, medal: "🥉")
        }
    }

    @ViewBuilder
    private func place(_ index: Int, medal: String) -> some View {
        if rows.indices.contains(index) {
            VStack(spacing: 2) {
                ZStack(alignment: .bottomTrailing) {
                    ProfilePicture(name: rows[index].displayName, path: rows[index].photoPath,
                                   size: index == 0 ? 56 : 44)
                    Text(medal).font(index == 0 ? .title2 : .title3)
                        .offset(x: 6, y: 6)
                }
                Text(rows[index].displayName).font(.subheadline.bold()).lineLimit(1)
                Text("\(rows[index].points) pts").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
