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
                    Picker("Per", selection: $period) {
                        ForEach(Period.allCases, id: \.self) { Text("per \($0.word)") }
                    }
                    .pickerStyle(.segmented)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") { next() }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.11, green: 0.16, blue: 0.31), Color(red: 0.06, green: 0.08, blue: 0.16)]
                : [Color(red: 0.80, green: 0.86, blue: 0.99), Color(red: 0.94, green: 0.95, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct HabitFormSection<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
        }
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
