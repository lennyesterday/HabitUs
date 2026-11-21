import SwiftUI
import HabitCore

// My habits, New Habit, Join (SPEC section 4, Home). Area A.
// One card per habit group: picture or icon on top, members, name, points and rank.

struct HomeView: View {
    @State private var cards: [GameCard] = []
    @State private var profile: Profile?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                HomeBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        header

                        HStack(spacing: 12) {
                            Button {
                                showCreate = true
                            } label: {
                                HomeActionLabel(title: "New Habit", symbol: "plus", isPrimary: true)
                            }
                            .buttonStyle(HomeActionButtonStyle(isPrimary: true))

                            Button {
                                showJoin = true
                            } label: {
                                HomeActionLabel(title: "Join Habit", symbol: "person.2.fill", isPrimary: false)
                            }
                            .buttonStyle(HomeActionButtonStyle(isPrimary: false))
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.bold())
                                .foregroundStyle(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                        }

                        if cards.isEmpty && !isLoading {
                            emptyState
                        }

                        ForEach(cards) { card in
                            NavigationLink {
                                GameScreen(groupId: card.id)
                            } label: {
                                GameCardView(card: card)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
                .refreshable { await load() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { Task { await load() } }
            .sheet(isPresented: $showProfile) {
                ProfileView(profile: $profile)
            }
            .sheet(isPresented: $showCreate, onDismiss: { Task { await load() } }) {
                CreateGroupView()
            }
            .sheet(isPresented: $showJoin, onDismiss: { Task { await load() } }) {
                JoinView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                Text("Habitract")
                    .font(Theme.title(32))
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                showProfile = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ProfilePicture(name: profile?.displayName ?? "?", path: profile?.photoPath, size: 46)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    Image(systemName: "gearshape.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.brand)
                        .padding(4)
                        .background(.white, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }
            .accessibilityLabel("Profile and settings")
        }
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🌱")
                .font(.system(size: 56))
            Text("No habits yet")
                .font(Theme.title(24))
                .foregroundStyle(.primary)
            Text("Start a habit with your friends, or join with a code from one of them.")
                .font(.system(.subheadline, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.12), radius: 0, y: 4)
        }
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
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
        isLoading = false
    }
}

/// A simple action with a clear icon and label.
private struct HomeActionLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(.subheadline, design: .default).weight(.bold))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 54)
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
    }
}

private struct HomeActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        configuration.label
            .background(isPrimary ? Theme.brand : Color(.secondarySystemBackground), in: shape)
            .overlay(shape.strokeBorder(isPrimary ? Color.white.opacity(0.22) : Color.primary.opacity(0.24), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A soft blue backdrop for Home, with a subtle pattern inspired by the welcome screen.
struct HomeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        LinearGradient(
            colors: isDark
                ? [Color(red: 0.14, green: 0.23, blue: 0.46), Color(red: 0.05, green: 0.08, blue: 0.20)]
                : [Color(red: 0.64, green: 0.76, blue: 0.98), Color(red: 0.88, green: 0.92, blue: 1.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Canvas { context, size in
                for x in stride(from: 12.0, through: size.width, by: 30.0) {
                    for y in stride(from: 12.0, through: size.height, by: 30.0) {
                        let dot = CGRect(x: x, y: y, width: 3, height: 3)
                        context.fill(Path(ellipseIn: dot), with: .color(isDark ? .white.opacity(0.07) : .blue.opacity(0.08)))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

/// Cards sink in a little when pressed.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// One habit group on Home: picture or icon, members, name, status, points and rank.
struct GameCardView: View {
    let card: GameCard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupBanner(group: card.group, height: 112, cornerRadius: 0)
                .overlay(alignment: .bottomLeading) {
                    memberStack
                        .offset(x: 12, y: 22)
                }
                .overlay(alignment: .topTrailing) {
                    if card.isOwner {
                        Pill(text: "Owner", emoji: "👑", dark: false)
                            .padding(10)
                    }
                }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.group.name)
                        .font(Theme.title(24))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.system(.subheadline, design: .default).weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if let points = card.myPoints {
                        Pill(text: "\(points) pts")
                    }
                    if let rank = card.myRank {
                        Text("#\(rank) of \(card.members.count)")
                            .font(.system(.caption, design: .default).weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, card.members.isEmpty ? 12 : 30)
            .padding(.bottom, 8)
        }
        .padding(8)
        .background {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.12), radius: 0, y: 4)
        }
        .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        .contentShape(Rectangle())
    }

    /// Profile pictures of the members, overlapping, on the edge of the picture.
    private var memberStack: some View {
        HStack(spacing: -12) {
            ForEach(card.members.prefix(6)) { member in
                ProfilePicture(name: member.displayName, path: member.photoPath, size: 44)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
            if card.members.count > 6 {
                Text("+\(card.members.count - 6)")
                    .font(.system(.caption, design: .default).bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.ink, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
        }
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
                let requests = card.openRequests == 1 ? "1 request" : "\(card.openRequests) requests"
                return card.isOwner
                    ? "Lobby · \(card.acceptedCount) of 3 · \(requests)"
                    : "Waiting for start · \(card.acceptedCount) of 3"
            case .active:
                let round = "\(group.habit) · Round \(currentRound(of: group, now: Date()))"
                if let done = card.myDone {
                    return "\(round) · \(done)/\(group.target) done"
                }
                return round
            case .ended:
                return "\(group.habit) · Ended"
            }
        }
    }
}

/// The wide picture on top of a group card: the group picture, or the icon on a colored panel.
struct GroupBanner: View {
    let group: HabitGroup
    var height: CGFloat = 140
    var cornerRadius: CGFloat = 22

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            GroupEmojiBackground(group: group)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(group.icon)
                    .font(.system(size: height * 0.5))
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: group.photoPath) {
            image = nil
            if let path = group.photoPath {
                image = try? await PictureService.load(path: path)
            }
        }
    }
}

/// The same stable, emoji-inspired background for the group banner and its task card.
struct GroupEmojiBackground: View {
    let group: HabitGroup
    @Environment(\.colorScheme) private var colorScheme
    @State private var emojiHue: Double?

    var body: some View {
        let bytes = group.id.uuid
        let hue = emojiHue ?? (Double(bytes.0) / 255.0 * 0.22 + 0.52).truncatingRemainder(dividingBy: 1)
        let isDark = colorScheme == .dark
        let base = Color(hue: hue, saturation: isDark ? 0.31 : 0.22, brightness: isDark ? 0.29 : 0.92)
        let accent = Color(hue: hue, saturation: isDark ? 0.38 : 0.29, brightness: isDark ? 0.21 : 0.85)
        let pattern = Int(bytes.1) % 3
        let angle = Double(Int(bytes.2) % 51 - 25)
        let position = 0.12 + CGFloat(bytes.3) / 255 * 0.76

        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack {
                LinearGradient(colors: [base, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                if pattern == 0 {
                    Circle()
                        .fill(.white.opacity(isDark ? 0.05 : 0.35))
                        .frame(width: height * 1.4, height: height * 1.4)
                        .position(x: geometry.size.width * position, y: height * 0.25)
                } else if pattern == 1 {
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(.white.opacity(isDark ? 0.10 : 0.45), lineWidth: 2)
                        .frame(width: height * 1.7, height: height * 0.8)
                        .rotationEffect(.degrees(angle))
                        .position(x: geometry.size.width * position, y: height * 0.6)
                } else {
                    Capsule()
                        .fill(.white.opacity(isDark ? 0.05 : 0.30))
                        .frame(width: height * 1.9, height: height * 0.38)
                        .rotationEffect(.degrees(angle))
                        .position(x: geometry.size.width * position, y: height * 0.5)
                }
                // Small, stable emoji motifs sit behind the main content.
                ForEach(0..<12, id: \.self) { index in
                    let column = index % 4
                    let row = index / 4
                    let shift = CGFloat((Int(bytes.4) + index * 37) % 21 - 10) / 100
                    Text(group.icon)
                        .font(.system(size: min(max(height * 0.13, 12), 19)))
                        .rotationEffect(.degrees(Double((Int(bytes.5) + index * 29) % 41 - 20)))
                        .opacity(isDark ? 0.13 : 0.16)
                        .position(x: geometry.size.width * (CGFloat(column) + 0.5 + shift) / 4,
                                  y: height * (CGFloat(row) + 0.5 + shift) / 3)
                }
            }
            .clipped()
        }
        .accessibilityHidden(true)
        .task(id: group.icon) { emojiHue = dominantEmojiHue(group.icon) }
    }
}

/// Find a colorful tone in the rendered emoji; neutral emoji use the group-ID fallback.
private func dominantEmojiHue(_ emoji: String) -> Double? {
    let size = 48
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    let image = renderer.image { _ in
        let font = UIFont.systemFont(ofSize: 38)
        let text = emoji as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: (CGFloat(size) - textSize.width) / 2,
                              y: (CGFloat(size) - textSize.height) / 2), withAttributes: attributes)
    }
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                          CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drewImage else { return nil }

    // Hue wraps around at red, so average it as points on a circle.
    var x = 0.0
    var y = 0.0
    var total = 0.0
    for index in stride(from: 0, to: pixels.count, by: 4) {
        let alpha = Double(pixels[index + 3]) / 255
        guard alpha > 0.5 else { continue }
        let red = min(Double(pixels[index]) / 255 / alpha, 1)
        let green = min(Double(pixels[index + 1]) / 255 / alpha, 1)
        let blue = min(Double(pixels[index + 2]) / 255 / alpha, 1)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        UIColor(red: red, green: green, blue: blue, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        guard saturation > 0.25, brightness > 0.2 else { continue }
        let weight = Double(saturation) * alpha
        x += cos(Double(hue) * 2 * .pi) * weight
        y += sin(Double(hue) * 2 * .pi) * weight
        total += weight
    }
    guard total > 20, hypot(x, y) / total > 0.2 else { return nil }
    let hue = atan2(y, x) / (2 * .pi)
    return hue < 0 ? hue + 1 : hue
}

#Preview("Card") {
    let group = HabitGroup(id: UUID(), name: "Gym Crew", habit: "Gym", icon: "🏋️", photoPath: nil, target: 3,
                           period: .week, endOn: nil, rulesText: "", inviteCode: "ABC234", ownerId: UUID(),
                           startedOn: Date(), endedEarlyAt: nil)
    let members = ["Lenny", "Bene", "Vincent"].map {
        Member(id: UUID(), userId: UUID(), displayName: $0, photoPath: nil, status: .accepted, signature: "")
    }
    return ZStack {
        HomeBackground()
        GameCardView(card: GameCard(group: group, myStatus: .accepted, isOwner: true, acceptedCount: 3,
                                    openRequests: 0, members: members, myPoints: 136, myRank: 2, myDone: 2))
            .padding()
    }
}

#Preview("Home – Light") {
    HomeView()
        .preferredColorScheme(.light)
}

#Preview("Home – Dark") {
    HomeView()
        .preferredColorScheme(.dark)
}
