import SwiftUI
import HabitCore

// Winner and final ranking, shown when the session has ended. Area C.

struct ResultsView: View {
    let data: GroupData

    var body: some View {
        let rows = data.leaderboard(now: Date())
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Challenge finished")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                    if endedBecauseTooFew {
                        Text("Fewer than \(minimumPlayers) players were left, so the game stopped.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if let winner = rows.first {
                    VStack(spacing: -4) {
                        Text("👑").font(.system(size: 50)).zIndex(1)
                        ProfilePicture(name: winner.displayName, path: winner.photoPath, size: 120)
                            .overlay(Circle().stroke(.white, lineWidth: 5))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
                    }
                    VStack(spacing: 2) {
                        Text("\(winner.displayName) kept the habit best")
                            .font(Theme.title(26))
                            .multilineTextAlignment(.center)
                        Text("\(winner.points) pts")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
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

    /// Ended early with fewer than 3 players: someone left (006_leave_messages.sql), not the owner's button.
    private var endedBecauseTooFew: Bool {
        data.group.endedEarlyAt != nil && data.accepted.count < minimumPlayers
    }
}
