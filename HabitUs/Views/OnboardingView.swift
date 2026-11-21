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
    }

    private let pages = [
        Page(symbols: ["person.2.fill", "signature"], color: Color(red: 0.42, green: 0.36, blue: 0.95),
             title: "Pick a habit together",
             text: "Start a group with your friends, choose how often, and everyone signs the contract."),
        Page(symbols: ["camera.fill"], color: Color(red: 0.98, green: 0.55, blue: 0.30),
             title: "Prove it live",
             text: "Every task is proven with a live photo from the camera. No old pictures from the library."),
        Page(symbols: ["hand.thumbsup.fill", "hand.thumbsdown.fill"], color: Color(red: 0.18, green: 0.72, blue: 0.55),
             title: "Your group checks",
             text: "Everyone sees every proof. If more than half give a 👎, it does not count."),
        Page(symbols: ["flame.fill", "trophy.fill"], color: Color(red: 0.95, green: 0.38, blue: 0.55),
             title: "Keep the streak",
             text: "Points for every task, a bonus for full rounds and streaks. Who delivers the most?"),
    ]

    var body: some View {
        ZStack {
            (colorScheme == .dark
                ? Color(red: 0.10, green: 0.10, blue: 0.10)
                : Color(red: 0.97, green: 0.96, blue: 0.93))
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    if page > 0 && page <= pages.count {
                        Button("Skip") { done() }
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(.secondary)
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
                .buttonStyle(OnboardingButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("Logo")
                .resizable()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 34))
                .frame(height: 340)
            Text("Welcome to\nHabitract")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            Text("Build habits together with your friends.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.secondary)
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
                .font(.system(size: 32, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
            Text(page.text)
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0...pages.count, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(index == page ? 1 : 0.25))
                    .frame(width: index == page ? 22 : 8, height: 8)
            }
        }
        .animation(.spring, value: page)
    }
}

/// A quiet illustration on a soft surface for each idea.
private struct Illustration: View {
    let symbols: [String]
    let color: Color

    var body: some View {
        HStack(spacing: 18) {
            ForEach(symbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: symbols.count == 1 ? 72 : 52, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 220, height: 180)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 36))
        .frame(height: 220)
    }
}

private struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.primary.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
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
