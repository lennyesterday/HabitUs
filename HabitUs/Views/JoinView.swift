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
            Form {
                Section {
                    TextField("Invite code", text: $code)
                        .font(.title2.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { code = String(code.uppercased().prefix(6)) }
                } footer: {
                    Text("6 characters, from the owner of the game.")
                }
                if errorMessage != nil {
                    ErrorText(message: errorMessage)
                }
            }
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Next") { Task { await next() } }
                    }
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
                        Text("The owner has to accept you. You find the game on Home.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
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
