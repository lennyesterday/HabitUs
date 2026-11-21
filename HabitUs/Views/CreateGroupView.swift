import SwiftUI
import HabitCore

// Name, habit, how often, per what, end, rules (R4). Then contract, then the invite code. Area A.

struct CreateGroupView: View {
    private enum Step: Hashable {
        case contract
        case created(code: String)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var path: [Step] = []
    @State private var name = ""
    @State private var habit = ""
    @State private var icon = "🎯"
    @State private var showEmojiPicker = false
    @State private var period = Period.week
    @State private var target = 3
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date()
    @State private var rulesText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HabitFormIntro(title: "Build your habit", subtitle: "Set a goal and invite your friends.", symbol: "sparkles")
                    HabitFormSection(title: "Group", symbol: "person.2.fill") {
                    TextField("Name, for example Gym Crew", text: $name)
                    Divider()
                    TextField("Habit, for example Gym", text: $habit)
                    Divider()
                    Button {
                        showEmojiPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Text(icon).font(.title)
                        }
                    }
                }

                HabitFormSection(title: "How often", symbol: "calendar") {
                    HStack(spacing: 8) {
                        ForEach(Period.allCases, id: \.self) { option in
                            Button {
                                period = option
                            } label: {
                                Text("per \(option.word)")
                                    .font(.system(.subheadline, design: .default).weight(.bold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(period == option ? Color.white : Color.primary)
                                    .background(period == option ? Theme.brand : Color(.tertiarySystemBackground),
                                                in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(period == option ? .isSelected : [])
                        }
                    }
                    Divider()
                    Stepper("\(target) per \(period.word)", value: $target, in: 1...period.maxTarget)
                }

                HabitFormSection(title: "End", symbol: "flag.fill") {
                    Toggle("End date", isOn: $hasEndDate)
                    Divider()
                    if hasEndDate {
                        DatePicker("Ends on", selection: $endDate, in: Date()..., displayedComponents: .date)
                        HStack {
                            shortcut("4 weeks", days: 28)
                            shortcut("3 months", months: 3)
                            shortcut("6 months", months: 6)
                        }
                    } else {
                        Text("Open end: the owner finishes the challenge.")
                            .foregroundStyle(.secondary)
                    }
                }

                HabitFormSection(title: "Rules", symbol: "text.alignleft") {
                    TextField("Your own rules, for example: the photo must show the gym",
                              text: $rulesText, axis: .vertical)
                        .lineLimit(3...8)
                }

                    if errorMessage != nil {
                        ErrorText(message: errorMessage)
                    }
                    Button("Next") { next() }
                        .buttonStyle(ChunkyButtonStyle())
                }
                .padding(20)
            }
            .background(HabitFormBackground())
            .tint(.primary)
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: period) { target = min(target, period.maxTarget) }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPicker { icon = $0 }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .contract:
                    ContractView(contract: contract) { signature in
                        let group = try await GroupService.createGroup(
                            name: name, habit: habit, icon: icon, target: target, period: period,
                            endOn: endOn, rulesText: rulesText, signature: signature)
                        path.append(.created(code: group.inviteCode))
                    }
                case .created(let code):
                    GroupCreatedView(code: code) { dismiss() }
                }
            }
        }
    }

    private var endOn: Date? {
        hasEndDate ? DayFormat.lisbonDay(fromPicked: endDate) : nil
    }

    private var contract: Contract {
        Contract(name: name, habit: habit, icon: icon, target: target, period: period, endOn: endOn,
                 rulesText: rulesText)
    }

    private func shortcut(_ title: String, days: Int = 0, months: Int = 0) -> some View {
        Button(title) {
            let calendar = Calendar.current
            let base = calendar.date(byAdding: .month, value: months, to: Date()) ?? Date()
            endDate = calendar.date(byAdding: .day, value: days, to: base) ?? base
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func next() {
        do {
            try validateGroup(name: name, habit: habit, icon: icon, target: target, period: period,
                              endOn: endOn, today: localDay(Date()))
            errorMessage = nil
            path.append(.contract)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Shared visual treatment for the first create and join screens.
struct HabitFormBackground: View {
    var body: some View { HomeBackground() }
}

struct HabitFormIntro: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(.black)
                .frame(width: 54, height: 54)
                .background(Theme.sunshine, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.title2, design: .default).weight(.heavy))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

struct HabitFormSection<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.headline, design: .default).weight(.heavy))
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.10), radius: 0, y: 4)
        }
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .padding(.bottom, 4)
    }
}

/// Shows the invite code large, to copy or share (SPEC section 4).
struct GroupCreatedView: View {
    let code: String
    let done: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Group created 🎉")
                .font(.title.bold())
            Text("Send this code to your friends. You accept them in the lobby.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .textSelection(.enabled)
            HStack {
                Button("Copy", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = code
                }
                .buttonStyle(.bordered)
                ShareLink(item: "Join my habit on Habitract with the code \(code)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            Button("Done", action: done)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    CreateGroupView()
}
