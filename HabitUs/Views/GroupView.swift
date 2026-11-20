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
    @State private var isUploading = false
    @State private var showFinishConfirmation = false
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
                    header(points: myRow?.points ?? 0, rank: (myIndex ?? 0) + 1)

                    VStack(spacing: 0) {
                        Text(roundLabel(round: round, now: now))
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .tracking(4)
                        Text(periodTitle)
                            .font(Theme.title(46))
                            .shadow(color: .black.opacity(0.12), radius: 0, y: 4)
                    }
                    .foregroundStyle(Theme.ink)

                    TaskCard(data: data, now: now, isUploading: isUploading) {
                        showCamera = true
                    }

                    if let errorMessage {
                        ErrorText(message: errorMessage)
                    }

                    voteSection(now: now)

                    BonusCard(round: round, target: data.group.target, status: status, streak: myRow?.streak ?? 0)

                    Podium(rows: Array(rows.prefix(3)))

                    RankingRows(rows: rows, me: data.me)

                    NavigationLink {
                        LeaderboardView(rows: rows, me: data.me, round: round)
                    } label: {
                        Label("Leaderboard & chart", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: .white, ledgeColor: Color(white: 0.78),
                                                   textColor: Theme.brand))

                    HStack {
                        Rectangle().frame(height: 2)
                        Text("CHAT")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .tracking(3)
                        Rectangle().frame(height: 2)
                    }
                    .foregroundStyle(Theme.ink.opacity(0.25))

                    FeedView(data: data, onReact: react, onRetake: { showCamera = true })

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .onChange(of: data.messages.count + data.checkins.count) {
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
        .background(PaperBackground())
        .safeAreaInset(edge: .bottom) { messageBar }
        .navigationTitle("\(data.group.icon) \(data.group.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if data.isOwner {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Finish challenge", systemImage: "flag.checkered", role: .destructive) {
                        showFinishConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog("Finish the challenge for everyone?", isPresented: $showFinishConfirmation,
                            titleVisibility: .visible) {
            Button("Finish challenge", role: .destructive) {
                Task { await run { try await GroupService.finish(groupId: data.group.id) } }
            }
        } message: {
            Text("The leaderboard freezes and nobody can check in any more.")
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
            HStack(spacing: 10) {
                Pill(text: "\(points) pts", emoji: "🔥", dark: false)
                Pill(text: "#\(rank)", emoji: "🏆", dark: false)
            }
        }
        .padding(.top, 4)
    }

    /// A button that folds open the Tinder style deck with the photos of this round that I can
    /// still vote on, newest first. A shortcut, so nobody has to scroll through the chat to vote.
    /// The photos are still in the chat as well, and voting works in both places.
    private func voteSection(now: Date) -> some View {
        let current = currentRound(of: data.group, now: now)
        let toVote = data.checkins
            .filter {
                $0.kind == .photo && HabitCore.round(of: $0.day, in: data.group) == current
                    && data.canReact(to: $0, now: now) && data.myReaction(on: $0) == nil
            }
            .sorted { $0.createdAt > $1.createdAt }

        return VStack(spacing: 16) {
            Button {
                withAnimation(.spring(duration: 0.35)) { showVoteDeck.toggle() }
            } label: {
                HStack {
                    Text("🗳️  Vote on photos")
                    if !toVote.isEmpty {
                        Text("\(toVote.count)")
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
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
                VoteDeck(data: data, photos: toVote) { photo, kind in
                    react(photo, kind)
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
        case .day: return "TODAY"
        case .week: return "THIS WEEK"
        case .month: return "THIS MONTH"
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
                .font(.system(.body, design: .rounded))
                .padding(.leading, 6)
            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    showGifPicker = true
                } label: {
                    Text("GIF")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
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
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
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
                                createdAt: Date().addingTimeInterval(-60))]
        return GroupData(me: me, group: group, members: members, checkins: checkins, reactions: [],
                         messages: messages)
    }
}

#Preview {
    NavigationStack {
        GroupView(data: .preview) { }
    }
}
