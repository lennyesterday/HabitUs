import SwiftUI
import HabitCore

// My games, New Game, Join Game (SPEC section 4, Home). Area A.

struct HomeView: View {
    @State private var cards: [GameCard] = []
    @State private var profile: Profile?
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            showCreate = true
                        } label: {
                            Label("New Game", systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            showJoin = true
                        } label: {
                            Label("Join Game", systemImage: "person.badge.plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("My games") {
                    if cards.isEmpty {
                        Text("No games yet. Start one or join with a code from a friend.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(cards) { card in
                        NavigationLink {
                            GameScreen(groupId: card.id)
                        } label: {
                            GameCardRow(card: card)
                        }
                    }
                }

                if let errorMessage {
                    ErrorText(message: errorMessage)
                }
            }
            .navigationTitle(profile.map { "Hi \($0.displayName) 👋" } ?? "HabitUs")
            .toolbar {
                Button {
                    showProfile = true
                } label: {
                    ProfilePicture(name: profile?.displayName ?? "?", path: profile?.photoPath, size: 32)
                }
                .accessibilityLabel("Profile")
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(profile: $profile)
            }
            .refreshable { await load() }
            .onAppear { Task { await load() } }
            .sheet(isPresented: $showCreate, onDismiss: { Task { await load() } }) {
                CreateGroupView()
            }
            .sheet(isPresented: $showJoin, onDismiss: { Task { await load() } }) {
                JoinView()
            }
        }
    }

    private func load() async {
        do {
            if profile == nil {
                profile = try await AuthService.myProfile()
            }
            cards = try await GroupService.myGames()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One game on Home. The role and the status are visible on the card.
struct GameCardRow: View {
    let card: GameCard

    var body: some View {
        HStack(spacing: 12) {
            GroupBadge(group: card.group, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(card.group.name)
                        .font(.headline)
                    Spacer()
                    if card.isOwner {
                        Text("👑 Owner")
                            .font(.caption)
                    }
                }
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        let group = card.group
        switch card.myStatus {
        case .pending:
            return "Waiting for the owner"
        case .declined:
            return "Declined"
        case .accepted:
            switch phase(of: group, now: Date()) {
            case .lobby:
                let requests = card.openRequests == 1 ? "1 open request" : "\(card.openRequests) open requests"
                return card.isOwner
                    ? "Lobby · \(card.acceptedCount) of 3 · \(requests)"
                    : "Waiting for start · \(card.acceptedCount) of 3"
            case .active:
                let round = "Active · Round \(currentRound(of: group, now: Date()))"
                return group.endOn.map { "\(round) · ends \(Theme.dayText($0))" } ?? round
            case .ended:
                return "Ended"
            }
        }
    }
}

#Preview {
    HomeView()
}
