import SwiftUI
import HabitCore

// Enter the invite code, read the contract, sign it (R5). Area A.

struct JoinView: View {
    private enum Step: Hashable {
        case contract(Contract)
        case sent
    }

    @Environment(\.dismiss) private var dismiss
    @State private var path: [Step] = []
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HabitFormIntro(title: "Join your friends", subtitle: "Your next habit starts together.", symbol: "person.2.fill")
                    HabitFormSection(title: "Invite code", symbol: "envelope.open.fill") {
                        TextField("Invite code", text: $code)
                            .font(.title2.monospaced().weight(.bold))
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: code) { code = String(code.uppercased().prefix(6)) }
                        Text("6 characters, from the friend who started the habit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if errorMessage != nil {
                        ErrorText(message: errorMessage)
                    }
                    Button {
                        Task { await next() }
                    } label: {
                        if isWorking { ProgressView().tint(Color(.systemBackground)) } else { Text("Next") }
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .disabled(isWorking)
                }
                .padding(20)
            }
            .background(HabitFormBackground())
            .tint(.primary)
            .navigationTitle("Join a Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .contract(let contract):
                    ContractView(contract: contract) { signature in
                        try await GroupService.requestToJoin(code: code, signature: signature)
                        path.append(.sent)
                    }
                case .sent:
                    VStack(spacing: 16) {
                        Text("Request sent ✉️")
                            .font(.title.bold())
                        Text("The owner has to accept you. You find the habit on Home.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HabitFormBackground())
                    .navigationBarBackButtonHidden()
                }
            }
        }
    }

    private func next() async {
        isWorking = true
        do {
            let contract = try await GroupService.previewContract(code: code)
            errorMessage = nil
            path.append(.contract(contract))
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}

#Preview {
    JoinView()
}
