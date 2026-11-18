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
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                switch item {
                case .message(let message):
                    let author = data.member(message.userId)?.displayName ?? "Former member"
                    if let gifURL = message.gifURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("**\(author):** \(message.text)")
                            AnimatedGif(url: gifURL)
                                .frame(width: 200, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Text("**\(author):** \(message.text)")
                    }
                case .checkin(let checkin, _):
                    CheckinFeedRow(data: data, checkin: checkin)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One photo or pause in the feed, with "valid" or "invalid" (R17, R18).
private struct CheckinFeedRow: View {
    let data: GroupData
    let checkin: Checkin

    var body: some View {
        let author = data.member(checkin.userId)?.displayName ?? "Former member"
        let valid = data.isValid(checkin)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if checkin.kind == .photo {
                    Text("**\(author):** 📷 \(data.group.habit.uppercased()) · \(Theme.timeText(checkin.createdAt))")
                } else {
                    Text("**\(author):** ⏸ \(checkin.text)")
                }
                Spacer()
                Text(valid ? (checkin.kind == .photo ? "valid" : "accepted") : (checkin.kind == .photo ? "invalid" : "rejected"))
                    .font(.caption)
                    .foregroundStyle(valid ? Color.green : Color.red)
            }
            if let path = checkin.photoPath {
                ProofImage(path: path)
            }
            if !checkin.text.isEmpty && checkin.kind == .photo {
                Text(checkin.text).font(.callout)
            }
        }
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
        .frame(maxHeight: 280)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: path) {
            do {
                image = try await PhotoService.load(path: path)
            } catch {
                failed = true
            }
        }
    }
}
