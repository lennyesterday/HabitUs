import SwiftUI
import HabitCore

// Tasks of the round, countdown, camera button, progress of the others (R10, R14). Area C.
// A big colored card like the "today's game" card of the inspiration.

struct TaskCard: View {
    let data: GroupData
    let now: Date
    let isUploading: Bool
    let checkIn: () -> Void

    var body: some View {
        let group = data.group
        let status = data.taskStatus(of: data.me, now: now)
        let habit = group.habit.uppercased()

        VStack(spacing: 16) {
            HStack {
                Pill(text: status.open == 0 ? "All done" : "\(status.open) left",
                     emoji: status.open == 0 ? "🎉" : "🎯")
                Spacer()
                // R14: time left in the round, red under 24 hours.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    let left = timeLeft(in: group, now: context.date)
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                        Text(Theme.durationText(left))
                    }
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(left < 24 * 3600 ? .white : Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(left < 24 * 3600 ? Color.red : Color.white, in: Capsule())
                }
            }

            Text(group.icon)
                .font(.system(size: 64))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 6)

            // R10: one chip per task, or a progress bar with more than 7 tasks.
            if group.target <= 7 {
                HStack(spacing: 6) {
                    ForEach(1...group.target, id: \.self) { k in
                        let done = k <= status.done
                        let failed = !done && k <= status.done + status.failed
                        Image(systemName: done ? "checkmark" : (failed ? "xmark" : "circle.dotted"))
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(done ? Theme.ink : (failed ? .red : Color.primary))
                            .frame(width: 34, height: 34)
                            .background(done ? Color.white : Color.primary.opacity(0.12), in: Circle())
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ProgressView(value: Double(status.done), total: Double(group.target))
                        .tint(.primary)
                    Text("\(status.done) of \(group.target)")
                        .font(.system(.subheadline, design: .default).bold())
                        .foregroundStyle(.primary)
                }
            }

            if status.open > 0 {
                Button(action: checkIn) {
                    if isUploading {
                        ProgressView().tint(.black)
                    } else {
                        Label("Do \(habit) \(status.done + status.failed + 1)", systemImage: "camera.fill")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, ledgeColor: Color(white: 0.82), textColor: Theme.ink))
                .disabled(!status.canCheckInToday || isUploading)
                .opacity(status.canCheckInToday ? 1 : 0.6)

                if !status.canCheckInToday {
                    Text("Done for today. Come back tomorrow!")
                        .font(.system(.footnote, design: .default).bold())
                        .foregroundStyle(.primary)
                }
            } else {
                Text("You finished this round. See you next round! 💪")
                    .font(.system(.headline, design: .default))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }

            let others = othersText(now: now)
            if !others.isEmpty {
                Text(others)
                    .font(.system(.footnote, design: .default).weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background {
            GroupEmojiBackground(group: group)
                .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    /// "Bene 3/3 · Vincent 1/3"
    private func othersText(now: Date) -> String {
        data.accepted
            .filter { $0.userId != data.me }
            .map { "\($0.displayName) \(data.taskStatus(of: $0.userId, now: now).done)/\(data.group.target)" }
            .joined(separator: " · ")
    }
}
