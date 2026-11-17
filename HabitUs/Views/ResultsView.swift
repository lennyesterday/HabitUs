import SwiftUI
import HabitCore

// Winner and final ranking, shown when the session has ended. Area C.

struct ResultsView: View {
    let data: GroupData

    var body: some View {
        let rows = data.leaderboard(now: Date())
        List {
            if let winner = rows.first {
                Section {
                    VStack(spacing: 8) {
                        Text("🏆").font(.system(size: 64))
                        Text("\(winner.avatar) \(winner.displayName) wins")
                            .font(.title.bold())
                        Text("\(winner.points) points")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Section("Final ranking") {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack {
                        Text("#\(index + 1) \(row.avatar) \(row.displayName)")
                        Spacer()
                        Text("\(row.points) pts")
                    }
                }
            }
        }
        .navigationTitle("\(data.group.name) · Ended")
    }
}
