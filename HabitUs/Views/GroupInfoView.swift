import SwiftUI
import HabitCore

// Everything about one group: picture, habit, key facts, all members with their signature,
// the contract with the group's own rules, and how points work. Opened by tapping the member
// pictures at the top of the group screen. Read only. Area A.

struct GroupInfoView: View {
    let data: GroupData

    @State private var selectedPlayer: UUID?

    var body: some View {
        let group = data.group
        let now = Date()

        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    GroupBanner(group: group, height: 150)
                    Text(group.name)
                        .font(Theme.title(30))
                        .foregroundStyle(Theme.ink)
                    Text("\(group.icon) \(group.habit) · \(group.target)× per \(group.period.word)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                section("Facts") {
                    fact("Status", statusText(now: now), "flag.fill")
                    fact("How often", "\(group.target)× \(group.habit) per \(group.period.word)", "repeat")
                    fact("One round", roundLength, "calendar")
                    if let start = group.startedOn {
                        fact("Started", Theme.dayText(start), "play.fill")
                    }
                    fact("Ends", group.endOn.map(Theme.dayText) ?? "Open end: the owner finishes it", "flag.checkered")
                    if phase(of: group, now: now) == .active {
                        fact("This round", "Round \(currentRound(of: group, now: now)) · \(Theme.durationText(timeLeft(in: group, now: now))) left", "hourglass")
                    }
                    fact("Owner", data.member(group.ownerId)?.displayName ?? "–", "crown.fill")
                }

                section("Members · \(data.accepted.count)") {
                    ForEach(data.accepted) { member in
                        Button {
                            selectedPlayer = member.userId
                        } label: {
                            memberRow(member)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Contract & rules")
                        .font(Theme.title(22))
                        .foregroundStyle(Theme.ink)
                    ContractTerms(contract: Contract(group))
                }

                section("How points work") {
                    Text("""
                    • 20 points for every task done
                    • +25 % on a round where all tasks are done
                    • +5 % more for every full round in a row, at most +50 %
                    • A missed task gives 0, never minus points
                    • Same points: fewer pauses first, then the name
                    """)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
            }
            .padding(18)
        }
        .background(PaperBackground())
        .navigationDestination(item: $selectedPlayer) { userId in
            PlayerProfileView(data: data, userId: userId)
        }
        .navigationTitle("Group info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.title(22))
                .foregroundStyle(Theme.ink)
            VStack(spacing: 0) { content() }
                .background(.white, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fact(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.brand)
                .frame(width: 28)
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func memberRow(_ member: Member) -> some View {
        HStack(spacing: 12) {
            ProfilePicture(name: member.displayName, path: member.photoPath, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.userId == data.me ? "\(member.displayName) (you)" : member.displayName)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                    if member.userId == data.group.ownerId {
                        Text("👑")
                    }
                }
                Text("Signed the contract")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !member.signature.isEmpty {
                SignatureImage(signature: member.signature)
                    .frame(maxWidth: 90, maxHeight: 40)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var roundLength: String {
        switch data.group.period {
        case .day: return "1 day"
        case .week: return "7 days"
        case .month: return "28 days"
        }
    }

    private func statusText(now: Date) -> String {
        switch phase(of: data.group, now: now) {
        case .lobby: return "Waiting for the start"
        case .active: return "Running"
        case .ended: return "Finished"
        }
    }
}

#Preview {
    NavigationStack {
        GroupInfoView(data: .preview)
    }
}
