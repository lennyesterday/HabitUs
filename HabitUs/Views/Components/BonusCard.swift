import SwiftUI
import HabitCore

// Shows the round bonus you can get or already have (R21, R22), so the scoring is visible and fun. Area C.

struct BonusCard: View {
    let round: Int
    let target: Int
    let status: TaskStatus
    /// Complete rounds in a row before this one (or including it, if it is complete).
    let streak: Int

    var body: some View {
        let complete = status.open == 0 && status.failed == 0
        // A complete round already counts in the streak. Otherwise: what you get if you finish it.
        let percent = complete ? roundBonusPercent(completeRoundsInARow: streak)
            : (status.failed > 0 ? 0 : roundBonusPercent(completeRoundsInARow: streak + 1))
        let green = Color(red: 0.24, green: 0.58, blue: 0.48)

        VStack(spacing: 6) {
            Text("Round \(round)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(green, in: Capsule())
            Text("+\(percent) %")
                .font(Theme.title(40))
                .foregroundStyle(Theme.ink)
            Text("round bonus")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message(complete: complete, percent: percent))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(green)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(green.opacity(0.14), in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(green.opacity(0.25), lineWidth: 2))
    }

    private func message(complete: Bool, percent: Int) -> String {
        if complete {
            return streak > 1 ? "Round complete! 🔥 \(streak) rounds in a row" : "Round complete! Keep it going 🔥"
        }
        if status.failed > 0 {
            return "A task failed this round, so no bonus this time. Next round counts again!"
        }
        return "Finish all \(target) tasks this round to get +\(percent)% on its points."
    }
}
