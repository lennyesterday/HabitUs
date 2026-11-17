import SwiftUI
import HabitCore

// The rules as a contract and the typed signature (R4, R5, R8). Area A.
// Used when creating, when joining, and read only while a request is pending.

struct ContractView: View {
    let contract: Contract
    /// Called with the typed name. nil shows the contract read only.
    var sign: ((String) async throws -> Void)?
    var statusText: String?

    @State private var signature = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Contract")
                    .font(.largeTitle.bold())
                Text(contract.name)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 10) {
                    Text("We do **\(contract.habit) \(contract.target) \(contract.target == 1 ? "time" : "times") per \(contract.period.word)**. Every \(contract.period.word) is one round.")
                    Text(contract.endOn.map { "The challenge ends with the last full round before **\(Theme.dayText($0))**." }
                         ?? "The challenge has an **open end**. It ends when the owner finishes it.")
                    Text("Every task is proven with a **live photo** taken in the app. The group sees every photo.")
                    Text("If more than half of the other members press **X**, a photo or pause does not count.")
                    Text("20 points per task, bonus for complete rounds and streaks.")
                    Text("The rules cannot change after the start.")
                    if !contract.rulesText.isEmpty {
                        Text("Our rules")
                            .font(.headline)
                            .padding(.top, 6)
                        Text(contract.rulesText)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))

                if let statusText {
                    Label(statusText, systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                }

                if let sign {
                    TextField("Type your name to sign", text: $signature)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                    ErrorText(message: errorMessage)
                    Button {
                        Task {
                            isWorking = true
                            errorMessage = nil
                            do {
                                try validateSignature(signature)
                                try await sign(signature)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isWorking = false
                        }
                    } label: {
                        Group {
                            if isWorking { ProgressView() } else { Text("Sign") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isWorking)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContractView(contract: Contract(name: "Gym Crew", habit: "Gym", target: 3, period: .week,
                                    endOn: nil, rulesText: "Photo must show the gym."),
                 sign: { _ in })
}
