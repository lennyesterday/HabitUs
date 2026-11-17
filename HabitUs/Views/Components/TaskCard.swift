import SwiftUI
import HabitCore

// Tasks of the round, countdown, camera button, progress of the others (R10, R14). Area C.

struct TaskCard: View {
    let data: GroupData
    let now: Date
    let isUploading: Bool
    let checkIn: () -> Void

    var body: some View {
        let group = data.group
        let status = data.taskStatus(of: data.me, now: now)
        let round = currentRound(of: group, now: now)
        let dayInRound = (Calendar.current.dateComponents([.day], from: group.startedOn ?? now, to: now).day ?? 0)
            % group.period.rawValue + 1
        let habit = group.habit.uppercased()

        VStack(spacing: 12) {
            Text(group.period == .day ? "ROUND \(round)" : "ROUND \(round) · DAY \(dayInRound)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            // R10: one chip per task, or a progress bar with more than 7 tasks.
            if group.target <= 7 {
                FlowChips(items: (1...group.target).map { k in
                    let symbol = k <= status.done ? "✅" : (k <= status.done + status.failed ? "❌" : "⏳")
                    return "\(habit) \(k) \(symbol)"
                })
            } else {
                VStack {
                    ProgressView(value: Double(status.done), total: Double(group.target))
                    Text("\(status.done) of \(group.target)")
                        .font(.subheadline)
                }
            }

            // R14: time left in the round, red under 24 hours.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let left = timeLeft(in: group, now: context.date)
                Label("\(Theme.durationText(left)) left", systemImage: "timer")
                    .foregroundStyle(left < 24 * 3600 ? .red : .secondary)
            }

            if status.open > 0 {
                Button(action: checkIn) {
                    Group {
                        if isUploading {
                            ProgressView()
                        } else {
                            Label("Do \(habit) \(status.done + status.failed + 1)", systemImage: "camera.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!status.canCheckInToday || isUploading)

                if !status.canCheckInToday {
                    Text("You already checked in today. Come back tomorrow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("All done this round 🎉")
                    .font(.headline)
            }

            Text(othersText(now: now))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    /// "Bene 3/3 · Vincent 1/3"
    private func othersText(now: Date) -> String {
        data.accepted
            .filter { $0.userId != data.me }
            .map { "\($0.displayName) \(data.taskStatus(of: $0.userId, now: now).done)/\(data.group.target)" }
            .joined(separator: " · ")
    }
}

/// Task chips that wrap onto a second line when they do not fit.
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ViewThatFits {
            HStack { chips }
            VStack { chips }
        }
    }

    private var chips: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.subheadline.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.background, in: Capsule())
        }
    }
}
