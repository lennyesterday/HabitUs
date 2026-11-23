import SwiftUI
import HabitCore

// The main group screen (SPEC section 4, Group). Area B.
// Header with members, points and rank; the task card; the bonus; podium and rankings; the chat.
// GameScreen owns the data. This screen asks it to reload every 10 seconds (R25).

struct GroupView: View {
    let data: GroupData
    let reload: () async -> Void

    @State private var showCamera = false
    @State private var showGifPicker = false
    @State private var showPauseSheet = false
    @State private var selectedPlayer: UUID?
    @State private var showGroupInfo = false
    @State private var isUploading = false
    @State private var messageText = ""
    @State private var errorMessage: String?
    /// Whether the Tinder style vote deck under the task card is open.
    @State private var showVoteDeck = false

    var body: some View {
        let now = Date()
        let rows = data.leaderboard(now: now)
        let myIndex = rows.firstIndex { $0.userId == data.me }
        let myRow = myIndex.map { rows[$0] }
        let round = currentRound(of: data.group, now: now)
        let status = data.taskStatus(of: data.me, now: now)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    Text("\(data.group.icon) \(data.group.name)")
                        .font(Theme.title(32))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    header(points: myRow?.points ?? 0, rank: (myIndex ?? 0) + 1)

                    VStack(spacing: 0) {
                        Text(roundLabel(round: round, now: now))
                            .font(.system(.caption, design: .default).weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        Text(periodTitle)
                            .font(Theme.title(30))
                    }
                    .foregroundStyle(.primary)

                    if data.photoToRetake(now: now) != nil {
                        retakeCard(now: now)
                    }
                    if data.isOnHold(now: now) {
                        onHoldCard
                    }
                    if round < data.myFirstRound {
                        welcomeCard(catchUp: myRow?.catchUpPoints ?? 0)
                    }
                    if data.isOwner && !data.pending.isEmpty {
                        requestsCard
                    }

                    TaskCard(data: data, now: now, isUploading: isUploading,
                             checkIn: { showCamera = true }, pause: { showPauseSheet = true })

                    if let errorMessage {
                        ErrorText(message: errorMessage)
                    }

                    voteSection(now: now)

                    // Tapping the podium opens the full leaderboard with the chart.
                    NavigationLink {
                        LeaderboardView(rows: rows, me: data.me, round: round, target: data.group.target,
                                        status: status, streak: myRow?.streak ?? 0)
                    } label: {
                        Podium(rows: Array(rows.prefix(3)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityHint("Opens the leaderboard with the points chart")

                    RankingRows(rows: rows, me: data.me) { selectedPlayer = $0 }

                    VStack(alignment: .leading, spacing: 16) {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.system(.headline, design: .default).weight(.bold))
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                        FeedView(data: data, onReact: react, onRetake: { showCamera = true })
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground).opacity(0.55), in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .onChange(of: data.messages.count + data.checkins.count) {
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
        .background(HomeBackground())
        .safeAreaInset(edge: .bottom) { messageBar }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // R29: the code keeps working while the challenge runs.
            ToolbarItem(placement: .secondaryAction) {
                ShareLink(item: inviteText) {
                    Label("Invite friends", systemImage: "person.badge.plus")
                }
            }
        }
        .navigationDestination(item: $selectedPlayer) { userId in
            PlayerProfileView(data: data, userId: userId)
        }
        .navigationDestination(isPresented: $showGroupInfo) {
            GroupInfoView(data: data)
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                showCamera = false
                Task { await checkIn(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showGifPicker) {
            GifPicker { gif in
                showGifPicker = false
                Task { await run { try await ChatService.postGif(groupId: data.group.id, gif: gif) } }
            }
        }
        .sheet(isPresented: $showPauseSheet) {
            // R18: the sheet shows its own errors, then closes once the pause is posted.
            PauseSheet(habit: data.group.habit) { reason in
                try await CheckinService.addPause(groupId: data.group.id, reason: reason)
                errorMessage = nil
                await reload()
            }
            .presentationDetents([.medium, .large])
        }
        .refreshable { await reload() }
        .task {
            // R25: refresh every 10 seconds while the group screen is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if !Task.isCancelled { await reload() }
            }
        }
    }

    /// Overlapping member pictures with my points and my rank.
    private func header(points: Int, rank: Int) -> some View {
        VStack(spacing: 10) {
            // Tapping the member pictures opens the group info (members, contract, rules).
            Button {
                showGroupInfo = true
            } label: {
                HStack(spacing: -14) {
                    ForEach(data.accepted.prefix(6)) { member in
                        ProfilePicture(name: member.displayName, path: member.photoPath,
                                       size: member.userId == data.me ? 62 : 50)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .zIndex(member.userId == data.me ? 1 : 0)
                    }
                }
                .padding(10)
                .background(.white.opacity(0.7), in: Capsule())
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("Group info")
            .accessibilityHint("Shows all members, the contract and the rules")
            HStack(spacing: 10) {
                Pill(text: "\(points) pts")
                Pill(text: "#\(rank) of \(data.accepted.count)")
            }
        }
        .padding(.top, 4)
    }

    /// A button that folds open the Tinder style deck with the photos of this round that I can
    /// still vote on, newest first. A shortcut, so nobody has to scroll through the chat to vote.
    /// The photos are still in the chat as well, and voting works in both places.
    private func voteSection(now: Date) -> some View {
        let current = currentRound(of: data.group, now: now)
        // Photos of this round and pauses inside their 48 hours (R18) that still wait for my vote.
        // Pauses first, because their time runs out; then the newest first.
        let toVote = data.checkins
            .filter {
                ($0.kind == .pause || HabitCore.round(of: $0.day, in: data.group) == current)
                    && data.canReact(to: $0, now: now) && data.myReaction(on: $0) == nil
            }
            .sorted { a, b in
                if a.kind != b.kind { return a.kind == .pause }
                return a.createdAt > b.createdAt
            }
        let pausesWaiting = toVote.filter { $0.kind == .pause }.count

        return VStack(spacing: 16) {
            Button {
                withAnimation(.spring(duration: 0.35)) { showVoteDeck.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🗳️  Vote on photos & pauses")
                        // So nobody overlooks a pause: its 48 hours run out (R18).
                        if pausesWaiting > 0 {
                            Text("⏸ \(pausesWaiting) \(pausesWaiting == 1 ? "pause waits" : "pauses wait") for your vote")
                                .font(.system(.caption, design: .default).weight(.bold))
                                .foregroundStyle(Theme.rankColor(0))
                                .textCase(nil)
                        }
                    }
                    if !toVote.isEmpty {
                        Text("\(toVote.count)")
                            .font(.system(.subheadline, design: .default).weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Theme.rankColor(0), in: Capsule())
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showVoteDeck ? 180 : 0))
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, ledgeColor: Color(white: 0.78),
                                           textColor: Theme.brand))

            if showVoteDeck {
                VoteDeck(data: data, checkins: toVote) { checkin, kind in
                    react(checkin, kind)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    /// Like or 👎 from the chat or the vote deck (R15).
    private func react(_ checkin: Checkin, _ kind: ReactionKind?) {
        Task {
            await run {
                try await CheckinService.setReaction(groupId: data.group.id, checkinId: checkin.id, kind: kind)
            }
        }
    }

    private var periodTitle: String {
        switch data.group.period {
        case .day: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        }
    }

    private func roundLabel(round: Int, now: Date) -> String {
        guard data.group.period != .day, let start = data.group.startedOn else { return "ROUND \(round)" }
        let days = Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0
        return "ROUND \(round) · DAY \(days % data.group.period.rawValue + 1)"
    }

    /// A floating white bar with the GIF button, the text field and send.
    private var messageBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(.body, design: .default))
                .padding(.leading, 6)
            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    showGifPicker = true
                } label: {
                    Text("GIF")
                        .font(.system(.subheadline, design: .default).weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 38)
                        .ledgeCard(Theme.brand, radius: 12, depth: 3)
                }
                .accessibilityLabel("Send a GIF")
            } else {
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 38)
                        .ledgeCard(Theme.brand, radius: 12, depth: 3)
                }
                .accessibilityLabel("Send")
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func checkIn(_ image: UIImage) async {
        isUploading = true
        await run { try await CheckinService.addPhoto(groupId: data.group.id, image: image, caption: "") }
        isUploading = false
    }

    private func send() async {
        let text = messageText
        await run {
            try await ChatService.post(groupId: data.group.id, text: text)
            messageText = ""
        }
    }

    private var inviteText: String {
        "Join my habit on Habitract with the code \(data.group.inviteCode)"
    }

    // MARK: - Joining later (R29) and on hold (R30)

    /// R17: my photo was rejected. Shown at the top until I took a new one or the round ended.
    private func retakeCard(now: Date) -> some View {
        let left = Theme.durationText(timeLeft(in: data.group, now: now))
        let canToday = data.taskStatus(of: data.me, now: now).canCheckInToday
        return NoticeCard(emoji: "📸", title: "Your photo was rejected by the group",
                          text: canToday
                            ? "Take a new one before the round ends · \(left) left. After that the task is missed."
                            : "You already have a photo today. Take the new one tomorrow · \(left) left in this round.",
                          tint: .red) {
            if canToday {
                Button {
                    showCamera = true
                } label: {
                    Label("Retake photo", systemImage: "camera.fill")
                }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(isUploading)
            }
        }
    }

    /// Fewer than 3 players: nobody can check in until someone new is accepted.
    private var onHoldCard: some View {
        NoticeCard(emoji: "⏸️", title: "The game is on hold",
                   text: "Only \(data.accepted.count) \(data.accepted.count == 1 ? "player is" : "players are") left. It goes on as soon as there are \(minimumPlayers) again. Invite someone with the code \(data.group.inviteCode).") {
            ShareLink(item: inviteText) {
                Label("Invite friends", systemImage: "person.badge.plus")
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.brand, ledgeColor: Color(red: 0.0, green: 0.12, blue: 0.55),
                                           textColor: .white))
        }
    }

    /// I joined a running challenge and my first round has not started yet.
    private func welcomeCard(catchUp: Int) -> some View {
        NoticeCard(emoji: "👋", title: "Welcome! You start in round \(data.myFirstRound)",
                   text: "For the rounds before you joined, you got the average points of the others: \(catchUp) pts. Until then you can already chat and vote.") {
            EmptyView()
        }
    }

    /// Owner only: people who asked to join while the challenge runs.
    private var requestsCard: some View {
        NoticeCard(emoji: "✋", title: data.pending.count == 1 ? "1 join request" : "\(data.pending.count) join requests",
                   text: "Accepted players start in the next round and get the group average for the rounds before.") {
            VStack(spacing: 10) {
                ForEach(data.pending) { member in
                    HStack(spacing: 10) {
                        ProfilePicture(name: member.displayName, path: member.photoPath, size: 36)
                        Text(member.displayName)
                            .font(.system(.headline, design: .rounded))
                        Spacer()
                        Button("Decline", role: .destructive) {
                            Task { await run { try await GroupService.decide(membershipId: member.id, accept: false) } }
                        }
                        .buttonStyle(.bordered)
                        Button("Accept") {
                            Task { await run { try await GroupService.decide(membershipId: member.id, accept: true) } }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    /// Runs an action, shows its error, then reloads the group.
    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await reload()
    }
}

// MARK: - Preview data

extension GroupData {
    /// A running group with three players and some photos, only for the Xcode previews.
    static var preview: GroupData {
        let me = UUID(), bene = UUID(), vincent = UUID()
        let start = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let group = HabitGroup(id: UUID(), name: "Gym Crew", habit: "Gym", icon: "🏋️", photoPath: nil, target: 3,
                               period: .week, endOn: nil, rulesText: "", inviteCode: "ABC234", ownerId: me,
                               startedOn: localDay(start), endedEarlyAt: nil)
        let members = [(me, "Lenny"), (bene, "Bene"), (vincent, "Vincent")].map {
            Member(id: UUID(), userId: $0.0, displayName: $0.1, photoPath: nil, status: .accepted, signature: "")
        }
        func photo(_ user: UUID, daysAgo: Int) -> Checkin {
            let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            return Checkin(id: UUID(), groupId: group.id, userId: user, kind: .photo, photoPath: nil,
                           text: "", day: localDay(day), createdAt: day)
        }
        let checkins = [photo(me, daysAgo: 10), photo(me, daysAgo: 9), photo(me, daysAgo: 8),
                        photo(bene, daysAgo: 10), photo(bene, daysAgo: 8), photo(bene, daysAgo: 7),
                        photo(vincent, daysAgo: 9), photo(me, daysAgo: 2), photo(bene, daysAgo: 1)]
        let messages = [Message(id: UUID(), groupId: group.id, userId: bene, text: "let's go 🔥", gifURL: nil,
                                createdAt: Date().addingTimeInterval(-3600)),
                        Message(id: UUID(), groupId: group.id, userId: me, text: "leg day tomorrow", gifURL: nil,
                                createdAt: Date().addingTimeInterval(-60)),
                        Message(id: UUID(), groupId: group.id, userId: vincent, text: "Vincent left the group.",
                                gifURL: nil, createdAt: Date().addingTimeInterval(-30), isSystem: true)]
        return GroupData(me: me, group: group, members: members, checkins: checkins, reactions: [],
                         messages: messages)
    }
}

#Preview {
    NavigationStack {
        GroupView(data: .preview) { }
    }
}

#Preview("My photo was rejected") {
    var data = GroupData.preview
    let photo = Checkin(id: UUID(), groupId: data.group.id, userId: data.me, kind: .photo, photoPath: nil,
                        text: "", day: Date(), createdAt: Date())
    data.checkins.append(photo)
    data.reactions += data.accepted.filter { $0.userId != data.me }
        .map { Reaction(checkinId: photo.id, userId: $0.userId, kind: .x) }
    return NavigationStack {
        GroupView(data: data) { }
    }
}

#Preview("On hold, with a join request") {
    var data = GroupData.preview
    data.members.removeLast()
    data.members.append(Member(id: UUID(), userId: UUID(), displayName: "Mia", photoPath: nil,
                               status: .pending, signature: ""))
    return NavigationStack {
        GroupView(data: data) { }
    }
}

/// A card with an emoji, a title, a text and optional buttons under it.
/// Light and dark mode; `tint` gives it a colored border, for example red for a rejected photo.
private struct NoticeCard<Actions: View>: View {
    let emoji: String
    let title: String
    let text: String
    var tint: Color? = nil
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(tint ?? Color.primary)
                    Text(text)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            actions()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            if let tint {
                RoundedRectangle(cornerRadius: 22).strokeBorder(tint.opacity(0.6), lineWidth: 2)
            }
        }
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }
}
