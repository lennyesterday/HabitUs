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
    @State private var showGroupMenu = false
    @State private var confirmFinish = false
    @State private var actionError: String?

    var body: some View {
        content
            .task { await load() }
            .toolbar {
                if data != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showGroupMenu = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Group options")
                    }
                }
            }
            .overlay {
                if showGroupMenu, let data {
                    groupMenu(data)
                }
            }
            .confirmationDialog("Finish the challenge for everyone?", isPresented: $confirmFinish,
                                titleVisibility: .visible) {
                Button("Finish challenge", role: .destructive) {
                    Task { await finishChallenge() }
                }
            } message: {
                Text("The leaderboard freezes and nobody can check in any more.")
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

    private func groupMenu(_ data: GroupData) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showGroupMenu = false }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Group options")
                        .font(Theme.title(24))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { showGroupMenu = false } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(Color(.tertiarySystemBackground), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                if data.isOwner, data.myMembership?.status == .accepted {
                    menuOption("Change icon & picture", symbol: "photo", color: Theme.brand) {
                        showGroupMenu = false
                        showLook = true
                    }
                }
                if data.isOwner, phase(of: data.group, now: Date()) == .active {
                    menuOption("Finish challenge", symbol: "flag.checkered", color: .orange) {
                        showGroupMenu = false
                        confirmFinish = true
                    }
                }
                menuOption(leaveTitle(data), symbol: "rectangle.portrait.and.arrow.right", color: .red) {
                    showGroupMenu = false
                    confirmLeave = true
                }
                if data.isOwner {
                    menuOption("Delete group for everyone", symbol: "trash", color: .red) {
                        showGroupMenu = false
                        confirmDelete = true
                    }
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28))
            .padding(24)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func menuOption(_ title: String, symbol: String, color: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(color, in: RoundedRectangle(cornerRadius: 14))
                Text(title)
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func finishChallenge() async {
        do {
            try await GroupService.finish(groupId: groupId)
            await load()
        } catch {
            actionError = error.localizedDescription
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
        guard data.isOwner else {
            return "The group disappears for you. Your photos stay in the chat but no longer count."
        }
        let next = data.accepted
            .filter { $0.userId != data.me }
            .first   // members are sorted by the time they joined
        if let next {
            return "\(next.displayName) becomes the new owner. Your photos stay in the chat but no longer count."
        }
        return "You are the last member, so the group and all its photos are deleted."
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
