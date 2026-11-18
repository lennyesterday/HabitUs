import SwiftUI
import HabitCore

// The main group screen: header, task card, podium, feed and message field (SPEC section 4, Group). Area B.
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

    var body: some View {
        let now = Date()
        let rows = data.leaderboard(now: now)
        let myRank = (rows.firstIndex { $0.userId == data.me } ?? 0) + 1
        let myPoints = rows.first { $0.userId == data.me }?.points ?? 0

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        HStack(spacing: -8) {
                            ForEach(data.accepted) { member in
                                ProfilePicture(name: member.displayName, path: member.photoPath, size: 36)
                                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            }
                        }
                        Text("\(myPoints) pts · #\(myRank) 🏆")
                            .font(.headline)
                    }

                    TaskCard(data: data, now: now, isUploading: isUploading) {
                        showCamera = true
                    }

                    Podium(rows: Array(rows.prefix(3)))

                    ErrorText(message: errorMessage)

                    Divider().overlay(Text("Chat").font(.caption).padding(.horizontal, 6).background(.background))

                    FeedView(data: data)

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .onChange(of: data.messages.count + data.checkins.count) {
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    showGifPicker = true
                } label: {
                    Text("GIF")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 1.5))
                }
                .accessibilityLabel("Send a GIF")
                TextField("Message…", text: $messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("\(data.group.icon) \(data.group.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink("Leaderboard") {
                    LeaderboardView(rows: rows, target: data.group.target)
                }
            }
            if data.isOwner {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Finish challenge", role: .destructive) { showFinishConfirmation = true }
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
