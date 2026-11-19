import SwiftUI
import HabitCore

// Chat with text messages, photo check-ins and pauses, newest at the bottom (R25). Area B.

struct FeedView: View {
    let data: GroupData

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
                    CheckinFeedRow(data: data, checkin: checkin)
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

/// One photo or pause in the feed as a white card, with "valid" or "invalid" (R17, R18).
private struct CheckinFeedRow: View {
    let data: GroupData
    let checkin: Checkin

    var body: some View {
        let author = data.member(checkin.userId)
        let valid = data.isValid(checkin)

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
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

/// Loads a photo from the private bucket with the logged-in session.
private struct ProofImage: View {
    let path: String
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                Label("Photo could not be loaded", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 320)
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
