import SwiftUI
import HabitCore

// Chat with text messages, photo check-ins and pauses, newest at the bottom (R25). Area B.

struct FeedView: View {
    let data: GroupData
    /// Like or X on a check-in, or nil to take my reaction back (R15).
    let onReact: (Checkin, ReactionKind?) -> Void
    /// Opens the camera again after my photo was voted invalid (R17).
    let onRetake: () -> Void

    var body: some View {
        let items = data.feed()
        LazyVStack(alignment: .leading, spacing: 14) {
            if items.isEmpty {
                Text("Nothing here yet. Do your first task or say hi 👋")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            ForEach(items) { item in
                switch item {
                case .message(let message):
                    MessageBubble(data: data, message: message)
                case .checkin(let checkin, _):
                    CheckinFeedRow(data: data, checkin: checkin, onReact: onReact, onRetake: onRetake)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A chat bubble: mine on the right in blue, the others on the left in white with their picture.
private struct MessageBubble: View {
    let data: GroupData
    let message: Message

    var body: some View {
        let mine = message.userId == data.me
        let author = data.member(message.userId)
        HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 50) } else {
                ProfilePicture(name: author?.displayName ?? "?", path: author?.photoPath, size: 30)
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if !mine {
                    Text(author?.displayName ?? "Former member")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(.secondary)
                }
                if let gifURL = message.gifURL {
                    AnimatedGif(url: gifURL)
                        .frame(width: 200, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(mine ? .white : Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(mine ? Theme.brand : .white, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
                }
            }
            if !mine { Spacer(minLength: 50) }
        }
    }
}

/// One photo or pause in the feed as a white card, with "valid" or "invalid" (R17, R18),
/// the like and X buttons (R15) and, on my own invalid photo, a button to take a new one.
private struct CheckinFeedRow: View {
    let data: GroupData
    let checkin: Checkin
    let onReact: (Checkin, ReactionKind?) -> Void
    let onRetake: () -> Void

    var body: some View {
        let author = data.member(checkin.userId)
        let valid = data.isValid(checkin)
        let now = Date()

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProfilePicture(name: author?.displayName ?? "?", path: author?.photoPath, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(author?.displayName ?? "Former member")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                    Text(checkin.kind == .photo
                         ? "📸 \(data.group.habit) · \(Theme.timeText(checkin.createdAt))"
                         : "⏸ Pause · \(Theme.timeText(checkin.createdAt))")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(valid ? (checkin.kind == .photo ? "VALID" : "ACCEPTED")
                           : (checkin.kind == .photo ? "INVALID" : "REJECTED"))
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(valid ? Theme.rankColor(1) : Theme.rankColor(0), in: Capsule())
            }
            if let path = checkin.photoPath {
                ProofImage(path: path)
            }
            if !checkin.text.isEmpty {
                Text(checkin.text)
                    .font(.system(.callout, design: .rounded))
            }
            reactionBar(valid: valid, now: now)
            if !valid && checkin.kind == .photo && checkin.userId == data.me
                && data.taskStatus(of: data.me, now: now).canCheckInToday {
                Button {
                    onRetake()
                } label: {
                    Label("Retake photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButtonStyle())
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    /// 👍 and 👎 (the X of R15) with their counts, and a bar that shows how close the proof is
    /// to being thrown out, for example "1 of 2 👎 to invalidate" (R17, R18).
    /// Tapping my current reaction again takes it back. Disabled on my own proof, once it is
    /// invalid, and after the round (R15, R19).
    private func reactionBar(valid: Bool, now: Date) -> some View {
        let mine = data.myReaction(on: checkin)
        let enabled = data.canReact(to: checkin, now: now)
        let others = data.reactions.filter { $0.checkinId == checkin.id && $0.userId != checkin.userId }
        let likes = others.filter { $0.kind == .like }.count
        let xCount = others.filter { $0.kind == .x }.count
        // Smallest X count that is more than half of the other members.
        let needed = (data.accepted.count - 1) / 2 + 1

        let reject = Theme.rankColor(0)
        let invalidWord = checkin.kind == .photo ? "invalidate" : "reject"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                reactionButton("👍 \(likes)", selected: mine == .like, enabled: enabled,
                               label: "Like, \(likes)") {
                    onReact(checkin, mine == .like ? nil : .like)
                }
                reactionButton("👎 \(xCount)", selected: mine == .x, enabled: enabled,
                               label: "Thumbs down, \(xCount)") {
                    onReact(checkin, mine == .x ? nil : .x)
                }
                Spacer()
            }

            // One segment per 👎 needed. Filled segments are the 👎 already given.
            // Only shown once somebody pressed 👎, so a fresh proof stays clean.
            if xCount > 0 || !valid {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<needed, id: \.self) { index in
                            Capsule()
                                .fill(index < xCount ? reject : Theme.paper)
                                .frame(height: 6)
                        }
                    }
                    Text(valid
                         ? "\(min(xCount, needed)) of \(needed) 👎 to \(invalidWord)"
                         : "\(needed) of \(needed) 👎 · \(checkin.kind == .photo ? "invalid" : "rejected")")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(reject)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func reactionButton(_ text: String, selected: Bool, enabled: Bool, label: String,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(selected ? .white : Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Theme.brand : Theme.paper, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled || selected ? 1 : 0.5)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Loads a photo from the private bucket with the logged-in session.
/// `fill` makes it cover the whole space (used by the swipe cards in `VoteDeck`).
struct ProofImage: View {
    let path: String
    var fill = false
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                if fill {
                    Color.clear.overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else if failed {
                Label("Photo could not be loaded", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : 320)
        .background(fill ? Theme.ink : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .task(id: path) {
            do {
                image = try await PhotoService.load(path: path)
            } catch {
                failed = true
            }
        }
    }
}
