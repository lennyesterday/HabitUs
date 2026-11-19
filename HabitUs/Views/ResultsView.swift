import SwiftUI
import HabitCore

// Winner and final ranking, shown when the session has ended. Area C.

struct ResultsView: View {
    let data: GroupData

    var body: some View {
        let rows = data.leaderboard(now: Date())
        ScrollView {
            VStack(spacing: 24) {
                Text("CHALLENGE OVER")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .tracking(4)
                    .foregroundStyle(Theme.ink.opacity(0.7))

                if let winner = rows.first {
                    VStack(spacing: -4) {
                        Text("👑").font(.system(size: 50)).zIndex(1)
                        ProfilePicture(name: winner.displayName, path: winner.photoPath, size: 120)
                            .overlay(Circle().stroke(.white, lineWidth: 5))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "laurel.leading")
                        VStack(spacing: 0) {
                            Text("Champion")
                                .font(.system(.headline, design: .rounded).weight(.heavy))
                            Text(winner.displayName.uppercased())
                                .font(Theme.title(34))
                            Text("\(winner.points) pts")
                                .font(.system(.headline, design: .rounded).weight(.heavy))
                        }
                        Image(systemName: "laurel.trailing")
                    }
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.ink)
                }

                RankingRows(rows: rows, me: data.me)
            }
            .padding(18)
        }
        .background(PaperBackground())
        .navigationTitle("\(data.group.icon) \(data.group.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
