import SwiftUI
import HabitCore

// Rank, points, complete rounds, streak (R24). Area C.

struct LeaderboardView: View {
    let rows: [LeaderboardRow]
    let target: Int

    var body: some View {
        List(Array(rows.enumerated()), id: \.element.id) { index, row in
            HStack {
                Text("#\(index + 1)")
                    .font(.headline)
                    .frame(width: 36, alignment: .leading)
                VStack(alignment: .leading) {
                    Text("\(row.avatar) \(row.displayName)")
                        .font(.headline)
                    Text("\(row.completeRounds) complete rounds · streak \(row.streak) 🔥 · \(row.pauses) pauses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(row.points) pts")
                    .font(.headline)
            }
        }
        .navigationTitle("Leaderboard")
    }
}
