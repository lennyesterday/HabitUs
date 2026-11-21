import SwiftUI
import HabitCore

// Tinder style voting on the photos of the round (R15, R17). Area B.
// Swipe right = 👍, swipe left = 👎. While dragging, a big thumb shows what will happen.
// The deck only holds photos I can still vote on and have not voted on yet. Votes can still
// be changed in the chat.

struct VoteDeck: View {
    let data: GroupData
    let photos: [Checkin]
    let onVote: (Checkin, ReactionKind) -> Void

    /// Photos swiped away in this session. Hidden at once, before the reload brings my vote.
    @State private var swiped: Set<UUID> = []
    /// How far the top card is dragged right now.
    @State private var drag: CGSize = .zero

    /// How far a card has to be dragged before the vote counts.
    private let swipeDistance: CGFloat = 110
    private let cardHeight: CGFloat = 420

    var body: some View {
        let deck = photos.filter { !swiped.contains($0.id) }

        VStack(spacing: 14) {
            if let top = deck.first {
                ZStack {
                    // Up to two cards behind the top one, a bit smaller, so it looks like a pile.
                    ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { position, photo in
                        let isTop = position == 0
                        VoteCard(data: data, photo: photo, drag: isTop ? drag : .zero)
                            .frame(height: cardHeight)
                            .scaleEffect(1 - CGFloat(position) * 0.05)
                            .offset(y: CGFloat(position) * 12)
                            .offset(isTop ? drag : .zero)
                            .rotationEffect(.degrees(isTop ? Double(drag.width / 18) : 0))
                            .allowsHitTesting(isTop)
                    }
                }
                .frame(height: cardHeight + 24)
                // Simultaneous, so scrolling the screen still works when the finger starts on
                // the card. Only sideways movement moves the card.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            drag = CGSize(width: value.translation.width, height: value.translation.height / 4)
                        }
                        .onEnded { _ in
                            if drag.width > swipeDistance {
                                vote(top, .like)
                            } else if drag.width < -swipeDistance {
                                vote(top, .x)
                            } else {
                                withAnimation(.spring(duration: 0.3)) { drag = .zero }
                            }
                        }
                )

                // The same votes as buttons, for people who do not want to swipe.
                HStack(spacing: 40) {
                    roundButton("👎", label: "Thumbs down") { vote(top, .x) }
                    roundButton("👍", label: "Like") { vote(top, .like) }
                }

                Text("\(deck.count) \(deck.count == 1 ? "photo" : "photos") left to vote on")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            } else {
                VStack(spacing: 6) {
                    Text("✅").font(.largeTitle)
                    Text("All votes are done")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    Text("You can still change your votes in the chat.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    /// The card flies out to the side, then the vote is sent and the next card is on top.
    private func vote(_ photo: Checkin, _ kind: ReactionKind) {
        let direction: CGFloat = kind == .like ? 1 : -1
        withAnimation(.easeIn(duration: 0.2)) {
            drag = CGSize(width: direction * 600, height: drag.height)
        } completion: {
            swiped.insert(photo.id)
            drag = .zero
            onVote(photo, kind)
        }
    }

    private func roundButton(_ emoji: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 64, height: 64)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One photo as a big card: the photo, who took it and when, and the thumb preview while dragging.
private struct VoteCard: View {
    let data: GroupData
    let photo: Checkin
    let drag: CGSize

    var body: some View {
        let author = data.member(photo.userId)
        // 0 when the card is still, 1 when it is dragged far enough for the vote to count.
        let strength = min(abs(drag.width) / 110, 1)
        let isLike = drag.width > 0
        let color = isLike ? Theme.rankColor(1) : Theme.rankColor(0)

        ZStack(alignment: .bottomLeading) {
            if let path = photo.photoPath {
                ProofImage(path: path, fill: true)
            }

            // Name and time on a dark fade at the bottom, so it stays readable on any photo.
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 10) {
                ProfilePicture(name: author?.displayName ?? "?", path: author?.photoPath, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(author?.displayName ?? "Former member")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                    Text("📸 \(data.group.habit) · \(Theme.timeText(photo.createdAt))")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                }
                .foregroundStyle(.white)
            }
            .padding(16)

            // The preview: a colored tint and a big thumb that grow while dragging.
            color.opacity(strength * 0.25)
            Text(isLike ? "👍" : "👎")
                .font(.system(size: 110))
                .padding(18)
                .background(.white.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(color, lineWidth: 6))
                .scaleEffect(0.6 + strength * 0.4)
                .opacity(strength)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(color.opacity(strength), lineWidth: 6))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }
}
