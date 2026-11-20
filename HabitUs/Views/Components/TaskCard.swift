import SwiftUI
import HabitCore

// Tasks of the round, countdown, camera button, progress of the others (R10, R14). Area C.
// A big colored card like the "today's game" card of the inspiration.

struct TaskCard: View {
    let data: GroupData
    let now: Date
    let isUploading: Bool
    let checkIn: () -> Void

    /// Why the camera button is grey: on hold (R30), not my first round yet (R29), or done for today.
    private func waitingText(now: Date) -> String {
        if data.isOnHold(now: now) {
            return "On hold until there are \(minimumPlayers) players again."
        }
        if currentRound(of: data.group, now: now) < data.myFirstRound {
            return "You start in round \(data.myFirstRound). Get ready! 💪"
        }
        return "Done for today. Come back tomorrow!"
    }

    var body: some View {
        let group = data.group
        let status = data.taskStatus(of: data.me, now: now)
        let habit = group.habit.uppercased()
        let color = Theme.groupColor(group.id)

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
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
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
                            .foregroundStyle(done ? color : (failed ? .red : .white.opacity(0.8)))
                            .frame(width: 34, height: 34)
                            .background(done ? Color.white : Color.white.opacity(0.2), in: Circle())
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ProgressView(value: Double(status.done), total: Double(group.target))
                        .tint(.white)
                    Text("\(status.done) of \(group.target)")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(.white)
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
                .buttonStyle(ChunkyButtonStyle(color: .white, ledgeColor: Color(white: 0.82), textColor: color))
                .disabled(!status.canCheckInToday || isUploading)
                .opacity(status.canCheckInToday ? 1 : 0.6)

                if !status.canCheckInToday {
                    Text(waitingText(now: now))
                        .font(.system(.footnote, design: .rounded).bold())
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Text("You finished this round. See you next round! 💪")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            let others = othersText(now: now)
            if !others.isEmpty {
                Text(others)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .ledgeCard(color, radius: 30, depth: 8)
    }

    /// "Bene 3/3 · Vincent 1/3"
    private func othersText(now: Date) -> String {
        data.accepted
            .filter { $0.userId != data.me }
            .map { "\($0.displayName) \(data.taskStatus(of: $0.userId, now: now).done)/\(data.group.target)" }
            .joined(separator: " · ")
    }
}
