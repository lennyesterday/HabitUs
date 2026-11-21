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
                        .foregroundStyle(Color.primary)
                    Text("Round \(round) · points so far")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if !rows.isEmpty {
                    podium
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Rankings", systemImage: "trophy.fill")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.primary)
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        playerRow(row, index: index)
                    }
                    Text("Points: 20 per task · +25 % for a full round · +5 % more per round in a row (max +50 %)")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26))

                VStack(alignment: .leading, spacing: 16) {
                    Label("Points over time", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    chart.frame(height: 240)
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26))
            }
            .padding(18)
        }
        .background(HomeBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var podium: some View {
        HStack(alignment: .bottom, spacing: 10) {
            podiumPlace(1)
            podiumPlace(0)
            podiumPlace(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func podiumPlace(_ index: Int) -> some View {
        if rows.indices.contains(index) {
            let row = rows[index]
            VStack(spacing: 7) {
                Text(index == 0 ? "👑" : (index == 1 ? "🥈" : "🥉"))
                    .font(.title2)
                ProfilePicture(name: row.displayName, path: row.photoPath, size: index == 0 ? 68 : 54)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                Text(row.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                Text("\(row.points) pts")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(index + 1)")
                    .font(Theme.title(26))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: index == 0 ? 64 : 42)
                    .background(Theme.rankColor(index).opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 1)
        }
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
            Text("\(index + 1)")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.22), in: Circle())
            ProfilePicture(name: row.displayName, path: row.photoPath, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
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
                    .foregroundStyle(Color.primary)
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
        .background(row.userId == me ? Theme.brand.opacity(0.10) : Color(.tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
            row.userId == me ? Theme.brand.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1))
    }
}

#Preview {
    let data = GroupData.preview
    return NavigationStack {
        LeaderboardView(rows: data.leaderboard(now: Date()), me: data.me, round: 2)
    }
}
