import SwiftUI
import HabitCore

// Members, requests, Start Session (R6, R7). Area A.

struct LobbyView: View {
    let data: GroupData
    let reload: () async -> Void

    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        List {
            Section("Invite code") {
                HStack {
                    Text(data.group.inviteCode)
                        .font(.title.monospaced().bold())
                        .textSelection(.enabled)
                    Spacer()
                    ShareLink(item: "Join my HabitUs game with the code \(data.group.inviteCode)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }

            Section("Members · \(data.accepted.count) of at least 3") {
                ForEach(data.accepted) { member in
                    HStack {
                        ProfilePicture(name: member.displayName, path: member.photoPath)
                        Text(member.displayName)
                        Spacer()
                        if member.userId == data.group.ownerId {
                            Text("👑")
                        }
                    }
                }
            }

            if data.isOwner {
                Section("Requests") {
                    if data.pending.isEmpty {
                        Text("No open requests.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(data.pending) { member in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ProfilePicture(name: member.displayName, path: member.photoPath)
                                Text(member.displayName)
                            }
                            HStack(alignment: .center) {
                                Text("Signed:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                SignatureImage(signature: member.signature)
                            }
                            HStack {
                                Button("Accept") { act { try await GroupService.decide(membershipId: member.id, accept: true) } }
                                    .buttonStyle(.borderedProminent)
                                Button("Decline", role: .destructive) { act { try await GroupService.decide(membershipId: member.id, accept: false) } }
                                    .buttonStyle(.bordered)
                            }
                            .disabled(isWorking)
                        }
                    }
                }
            }

            Section {
                if data.isOwner {
                    Button {
                        act { try await GroupService.start(groupId: data.group.id) }
                    } label: {
                        Text("Start Session")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .disabled(isWorking || data.accepted.count < 3)
                    .opacity(data.accepted.count < 3 ? 0.5 : 1)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } else {
                    Label("Waiting for the owner to start.", systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("The session starts today. Open requests are declined and the code stops working.")
            }

            if errorMessage != nil {
                ErrorText(message: errorMessage)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PaperBackground())
        .navigationTitle("\(data.group.icon) \(data.group.name)")
        .refreshable { await reload() }
    }

    /// Runs an owner action, shows its error, then loads the lobby again.
    private func act(_ action: @escaping () async throws -> Void) {
        Task {
            isWorking = true
            do {
                try await action()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            await reload()
            isWorking = false
        }
    }
}
