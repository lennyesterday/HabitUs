import SwiftUI
import Charts
import HabitCore

// Rank, points, complete rounds, streak (R24), and how the points grew round by round. Area C.

struct LeaderboardView: View {
    let rows: [LeaderboardRow]
    let me: UUID
    let round: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Leaderboard")
                        .font(Theme.title(30))
                        .foregroundStyle(Theme.ink)
                    Text("Round \(round) · points so far")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                chart
                    .frame(height: 260)
                    .padding(.horizontal, 4)

                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        playerRow(row, index: index)
                    }
                    Text("Points: 20 per task · +25 % for a full round · +5 % more per round in a row (max +50 %)")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 26))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            }
            .padding(18)
        }
        .background(PaperBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// Points added up round by round, one line per player in their rank color.
    private var chart: some View {
        Chart {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let totals = row.pointsPerRound.reduce(into: [0]) { $0.append(($0.last ?? 0) + $1) }
                ForEach(Array(totals.enumerated()), id: \.offset) { roundIndex, total in
                    LineMark(x: .value("Round", roundIndex), y: .value("Points", total),
                             series: .value("Player", row.displayName))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                        .foregroundStyle(Theme.rankColor(index))
                    PointMark(x: .value("Round", roundIndex), y: .value("Points", total))
                        .foregroundStyle(Theme.rankColor(index))
                        .symbolSize(30)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: Array(0...max(1, rows.map(\.pointsPerRound.count).max() ?? 1))) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4]))
                AxisValueLabel {
                    if let round = value.as(Int.self) { Text(round == 0 ? "Start" : "R\(round)") }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4]))
                AxisValueLabel()
            }
        }
    }

    private func playerRow(_ row: LeaderboardRow, index: Int) -> some View {
        let color = Theme.rankColor(index)
        return HStack(spacing: 12) {
            ProfilePicture(name: row.displayName, path: row.photoPath, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("#\(index + 1)")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(color)
                    if row.userId == me {
                        Text("YOU")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.brand, in: Capsule())
                    }
                }
                Text(row.displayName)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text("\(row.completeRounds) full round\(row.completeRounds == 1 ? "" : "s") · streak \(row.streak) 🔥 · \(row.pauses) pause\(row.pauses == 1 ? "" : "s")")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(row.points)")
                .font(Theme.title(20))
                .foregroundStyle(.white)
                .frame(minWidth: 50, minHeight: 50)
                .background(color, in: Circle())
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.5), lineWidth: 2))
    }
}

#Preview {
    let data = GroupData.preview
    return NavigationStack {
        LeaderboardView(rows: data.leaderboard(now: Date()), me: data.me, round: 2)
    }
}
