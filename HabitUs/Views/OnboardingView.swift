import SwiftUI

// Shown the first time the app opens: a welcome page and one page per idea of Habitract.
// "Next" (or swiping) goes to the next page, the last one leads to sign up and log in. Area A.

struct OnboardingView: View {
    let done: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var page: Int

    /// `startPage` is only used by the previews.
    init(startPage: Int = 0, done: @escaping () -> Void) {
        self.done = done
        _page = State(initialValue: startPage)
    }

    private struct Page {
        let symbols: [String]
        let color: Color
        let title: String
        let text: String
        let highlight: String
    }

    private let pages = [
        Page(symbols: ["person.2.fill", "signature"], color: Color(red: 0.42, green: 0.36, blue: 0.95),
             title: "Pick a habit together",
             text: "Start a group with your friends, choose how often, and everyone signs the contract.",
             highlight: "signs the contract"),
        Page(symbols: ["camera.fill"], color: Color(red: 0.98, green: 0.55, blue: 0.30),
             title: "Prove it live",
             text: "Every task is proven with a live photo from the camera. No old pictures from the library.",
             highlight: "live photo"),
        Page(symbols: ["hand.thumbsup.fill", "hand.thumbsdown.fill"], color: Color(red: 0.18, green: 0.72, blue: 0.55),
             title: "Your group checks",
             text: "Everyone sees every proof. If more than half give a 👎, it does not count.",
             highlight: "more than half give a 👎"),
        Page(symbols: ["flame.fill", "trophy.fill"], color: Color(red: 0.95, green: 0.38, blue: 0.55),
             title: "Keep the streak",
             text: "Points for every task, a bonus for full rounds and streaks. Who delivers the most?",
             highlight: "bonus"),
    ]

    var body: some View {
        ZStack {
            BrandBackground(
                top: colorScheme == .dark ? Color(red: 0.12, green: 0.17, blue: 0.42) : Theme.brandLight,
                bottom: colorScheme == .dark ? Color(red: 0.03, green: 0.06, blue: 0.20) : Theme.brand
            )

            VStack {
                HStack {
                    Spacer()
                    if page > 0 && page <= pages.count {
                        Button("Skip") { done() }
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(height: 30)
                .padding(.horizontal, 24)

                TabView(selection: $page) {
                    welcome.tag(0)
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index]).tag(index + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                dots
                    .padding(.bottom, 20)

                Button(page == 0 ? "Let's go" : (page == pages.count ? "Get started" : "Next")) {
                    if page < pages.count {
                        withAnimation { page += 1 }
                    } else {
                        done()
                    }
                }
                .buttonStyle(ChunkyButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                // Soft rays behind the logo, like a sunrise.
                ForEach(0..<12) { index in
                    Capsule()
                        .fill(.white.opacity(0.12))
                        .frame(width: 18, height: 340)
                        .rotationEffect(.degrees(Double(index) * 15))
                }
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34))
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
            }
            .frame(height: 340)
            Text("Welcome to\nHabitract")
                .font(Theme.title(38))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 0, y: 3)
            (Text("Build habits ") + Text("together").foregroundStyle(Theme.sunshine).bold()
                + Text(" with your friends."))
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Illustration(symbols: page.symbols, color: page.color)
            Text(page.title)
                .font(Theme.title(32))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 0, y: 3)
            highlighted(page.text, page.highlight)
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    /// The text with one part in yellow and bold.
    private func highlighted(_ text: String, _ part: String) -> Text {
        guard let range = text.range(of: part) else { return Text(text) }
        return Text(text[..<range.lowerBound])
            + Text(text[range]).foregroundStyle(Theme.sunshine).bold()
            + Text(text[range.upperBound...])
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0...pages.count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == page ? 1 : 0.35))
                    .frame(width: index == page ? 22 : 8, height: 8)
            }
        }
        .animation(.spring, value: page)
    }
}

/// A tilted card with big white symbols that bounce in when the page appears.
private struct Illustration: View {
    let symbols: [String]
    let color: Color

    @State private var bounce = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36)
                .fill(color.opacity(0.45))
                .frame(width: 220, height: 180)
                .rotationEffect(.degrees(6))
                .offset(y: 10)
            RoundedRectangle(cornerRadius: 36)
                .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(width: 220, height: 180)
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
            HStack(spacing: 18) {
                ForEach(symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: symbols.count == 1 ? 80 : 60, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: bounce)
                }
            }
            .rotationEffect(.degrees(-4))
        }
        .frame(height: 220)
        .onAppear { bounce += 1 }
    }
}

#Preview("Welcome – Light") {
    OnboardingView { }
        .preferredColorScheme(.light)
}

#Preview("Welcome – Dark") {
    OnboardingView { }
        .preferredColorScheme(.dark)
}

#Preview("Photo page") {
    OnboardingView(startPage: 2) { }
}
