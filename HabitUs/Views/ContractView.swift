import SwiftUI
import PencilKit
import HabitCore

// The rules as a contract and the hand-drawn signature (R4, R5, R8). Area A.
// Used when creating, when joining, and read only while a request is pending.

struct ContractView: View {
    let contract: Contract
    /// Called with the signature as PNG. nil shows the contract read only.
    var sign: ((Data) async throws -> Void)?
    var statusText: String?

    @State private var drawing = PKDrawing()
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Contract")
                    .font(Theme.title(40))
                    .foregroundStyle(Theme.ink)
                Text("\(contract.icon) \(contract.name)")
                    .font(.title2)

                ContractTerms(contract: contract)

                if let statusText {
                    Label(statusText, systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                }

                if let sign {
                    SignaturePad(drawing: $drawing)
                    Text("Date: \(Theme.signatureDate(Date()))")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                    ErrorText(message: errorMessage)
                    Button {
                        Task {
                            isWorking = true
                            errorMessage = nil
                            do {
                                let png = SignaturePad.png(from: drawing) ?? Data()
                                try validateSignatureImage(png)
                                try await sign(png)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isWorking = false
                        }
                    } label: {
                        Group {
                            if isWorking { ProgressView().tint(.black) } else { Text("Sign") }
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .disabled(isWorking)
                }
            }
            .padding()
        }
        .background(PaperBackground())
    }
}

/// The contract text in a white card. Used when signing and in the group info, so both show the same words.
struct ContractTerms: View {
    let contract: Contract

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("We do **\(contract.habit) \(contract.target) \(contract.target == 1 ? "time" : "times") per \(contract.period.word)**. Every \(contract.period.word) is one round.")
            Text(contract.endOn.map { "The challenge ends with the last full round before **\(Theme.dayText($0))**." }
                 ?? "The challenge has an **open end**. It ends when the owner finishes it.")
            Text("Every task is proven with a **live photo** taken in the app. The group sees every photo.")
            Text("If more than half of the other members give a **👎**, a photo or pause does not count.")
            Text("20 points per task, bonus for complete rounds and streaks.")
            Text("The rules cannot change after the start.")
            Text("You can leave the group at any time.")
            if !contract.rulesText.isEmpty {
                Text("Our rules")
                    .font(.headline)
                    .padding(.top, 6)
                Text(contract.rulesText)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

#Preview {
    ContractView(contract: Contract(name: "Gym Crew", habit: "Gym", icon: "🏋️", target: 3, period: .week,
                                    endOn: nil, rulesText: "Photo must show the gym."),
                 sign: { _ in })
}
