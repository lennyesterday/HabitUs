import SwiftUI
import HabitCore

// Opens the right screen for a game card (SPEC section 4, Home table):
// pending → contract, lobby → Lobby, active → Group, ended → Results. Area A.

struct GameScreen: View {
    let groupId: UUID

    @State private var data: GroupData?
    @State private var errorMessage: String?

    var body: some View {
        content
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let data, let me = data.myMembership {
            switch (me.status, phase(of: data.group, now: Date())) {
            case (.pending, _):
                ContractView(contract: Contract(data.group),
                             statusText: "Waiting for the owner to accept your request.")
            case (.declined, _):
                Text("Your request was declined.")
                    .foregroundStyle(.secondary)
            case (.accepted, .lobby):
                LobbyView(data: data, reload: load)
            case (.accepted, .active):
                GroupView(data: data, reload: load)
            case (.accepted, .ended):
                ResultsView(data: data)
            }
        } else if let errorMessage {
            VStack(spacing: 12) {
                ErrorText(message: errorMessage)
                Button("Try again") { Task { await load() } }
            }
            .padding()
        } else {
            ProgressView()
        }
    }

    private func load() async {
        do {
            data = try await GroupService.load(groupId: groupId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
