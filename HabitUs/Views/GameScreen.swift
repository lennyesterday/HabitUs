import SwiftUI
import HabitCore

// Opens the right screen for a game card (SPEC section 4, Home table):
// pending → contract, lobby → Lobby, active → Group, ended → Results. Area A.

struct GameScreen: View {
    let groupId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var data: GroupData?
    @State private var errorMessage: String?
    @State private var confirmLeave = false
    @State private var confirmDelete = false
    @State private var showLook = false
    @State private var actionError: String?

    var body: some View {
        content
            .task { await load() }
            .toolbar {
                if let data {
                    ToolbarItem(placement: .secondaryAction) {
                        Button(leaveTitle(data), systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            confirmLeave = true
                        }
                    }
                    if data.isOwner, data.myMembership?.status == .accepted {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Change icon & picture", systemImage: "photo") {
                                showLook = true
                            }
                        }
                    }
                    if data.isOwner {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Delete group for everyone", systemImage: "trash", role: .destructive) {
                                confirmDelete = true
                            }
                        }
                    }
                }
            }
            .confirmationDialog(data.map(leaveTitle) ?? "Leave group", isPresented: $confirmLeave,
                                titleVisibility: .visible) {
                Button(data.map(leaveTitle) ?? "Leave group", role: .destructive) {
                    Task { await act { try await GroupService.leave(groupId: groupId) } }
                }
            } message: {
                Text(data.map(leaveMessage) ?? "")
            }
            .confirmationDialog("Delete this group for everyone?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete group", role: .destructive) {
                    Task { await act { try await GroupService.delete(groupId: groupId) } }
                }
            } message: {
                Text("All members, photos, points and messages are deleted. This cannot be undone.")
            }
            .sheet(isPresented: $showLook) {
                if let group = data?.group {
                    GroupLookView(group: group, saved: load)
                }
            }
            .alert("That did not work", isPresented: Binding(get: { actionError != nil },
                                                             set: { if !$0 { actionError = nil } })) {
                Button("OK") {}
            } message: {
                Text(actionError ?? "")
            }
    }

    private func leaveTitle(_ data: GroupData) -> String {
        switch data.myMembership?.status {
        case .pending: return "Withdraw request"
        case .declined: return "Remove from my habits"
        default: return "Leave group"
        }
    }

    private func leaveMessage(_ data: GroupData) -> String {
        guard data.myMembership?.status == .accepted else {
            return "The habit disappears from your Home."
        }
        let next = data.accepted
            .filter { $0.userId != data.me }
            .first   // members are sorted by the time they joined
        guard next != nil else {
            return "You are the last member, so the group and all its photos are deleted."
        }
        var parts = ["The group disappears for you and the chat says that you left."]
        if data.isOwner, let next {
            parts.append("\(next.displayName) becomes the new owner.")
        }
        parts.append("Your photos stay in the chat but no longer count.")
        if leavingPutsOnHold(data.group, acceptedBefore: data.accepted.count, now: Date()) {
            parts.append("Only \(data.accepted.count - 1) players would be left, so the game is on hold until someone new joins.")
        }
        return parts.joined(separator: " ")
    }

    /// Runs leave or delete, then goes back to Home.
    private func act(_ action: () async throws -> Void) async {
        do {
            try await action()
            dismiss()
        } catch {
            actionError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var content: some View {
        if let data, let me = data.myMembership {
            switch (me.status, phase(of: data.group, now: Date())) {
            case (.pending, _):
                ContractView(contract: Contract(data.group),
                             statusText: "Waiting for the owner to accept your request.")
            case (.declined, _):
                Text("Your request was declined. You can remove the habit with the menu at the top.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
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
