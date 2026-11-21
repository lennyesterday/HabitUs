import SwiftUI
import HabitCore

// Colors, texts and small helpers shared by all screens. Area A.

enum Theme {
    static let cardBackground = Color(.secondarySystemBackground)

    /// The blue of the app icon.
    static let brand = Color(red: 0.04, green: 0.20, blue: 0.76)
    /// Warm yellow for the main buttons, the "fun" color next to the calm blue.
    static let sunshine = Color(red: 1.0, green: 0.80, blue: 0.18)
    static let sunshineLedge = Color(red: 0.80, green: 0.58, blue: 0.10)
    static let brandLight = Color(red: 0.36, green: 0.48, blue: 1.0)

    /// Serif system font for expressive headings.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    /// "14 Feb", always the Lisbon calendar day the database means.
    static func dayText(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        style.timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .current
        return date.formatted(style)
    }

    /// "20 Nov 2026" for the date next to a signature.
    static func signatureDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// "Tue 18:40" for the feed.
    static func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    /// "3 days 2 h", "5 h 12 min" or "12 min" for the countdown (R14).
    static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let days = minutes / (24 * 60)
        let hours = (minutes / 60) % 24
        if days > 0 {
            return "\(days) \(days == 1 ? "day" : "days") \(hours) h"
        } else if hours > 0 {
            return "\(hours) h \(minutes % 60) min"
        } else {
            return "\(minutes) min"
        }
    }
}

extension Period {
    /// "day", "week" or "month".
    var word: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        }
    }
}

/// A red error text, shown under forms and buttons.
struct ErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A big rounded button with a thin darker edge underneath. It sinks in a little when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = .primary
    var ledgeColor: Color = Theme.sunshineLedge
    var textColor: Color = Color(.systemBackground)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline).weight(.semibold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// The blue gradient behind onboarding and login, with soft dots like a notebook page.
struct BrandBackground: View {
    var top: Color = Theme.brandLight
    var bottom: Color = Theme.brand

    var body: some View {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 18
                    for x in stride(from: 0, through: size.width, by: spacing) {
                        for y in stride(from: 0, through: size.height * 0.5, by: spacing) {
                            let fade = 1 - y / (size.height * 0.5)
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)),
                                         with: .color(.white.opacity(0.10 * fade)))
                        }
                    }
                }
            }
            .ignoresSafeArea()
    }
}

// MARK: - Redesign building blocks

extension Theme {
    /// Warm off-white behind the group screens.
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let ink = Color(red: 0.16, green: 0.16, blue: 0.18)

    /// One color per place on the leaderboard: coral, green, purple, then blue and orange.
    static let rankColors: [Color] = [
        Color(red: 0.90, green: 0.45, blue: 0.42),
        Color(red: 0.24, green: 0.58, blue: 0.48),
        Color(red: 0.62, green: 0.55, blue: 0.95),
        Color(red: 0.40, green: 0.60, blue: 0.95),
        Color(red: 0.95, green: 0.62, blue: 0.30),
    ]

    static func rankColor(_ index: Int) -> Color {
        rankColors[index % rankColors.count]
    }

    /// A stable color for a person without picture, picked from the letters of the name.
    static func avatarColor(_ name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return rankColors[sum % rankColors.count]
    }

    /// A stable color for a group without picture, picked from its id.
    static func groupColor(_ id: UUID) -> Color {
        let palette = [Color(red: 0.42, green: 0.36, blue: 0.95), Color(red: 0.18, green: 0.72, blue: 0.62),
                       Color(red: 0.98, green: 0.55, blue: 0.30), Color(red: 0.95, green: 0.38, blue: 0.55),
                       Color(red: 0.30, green: 0.60, blue: 0.36)]
        return palette[Int(id.uuid.0) % palette.count]
    }
}

/// The off-white background with soft dots, like the group screen of the inspiration.
struct PaperBackground: View {
    var body: some View {
        Theme.paper
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 16
                    for x in stride(from: 4, through: size.width, by: spacing) {
                        for y in stride(from: 4, through: size.height, by: spacing) {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)),
                                         with: .color(.black.opacity(0.035)))
                        }
                    }
                }
            }
            .ignoresSafeArea()
    }
}

/// A small dark capsule with a number and an emoji, like "136 pts" or "#2 🏆".
struct Pill: View {
    let text: String
    var emoji: String = ""
    var dark = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if !emoji.isEmpty { Text(emoji) }
        }
        .font(.system(.subheadline, design: .default).weight(.bold))
        .foregroundStyle(dark ? .white : Theme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(dark ? Color.black.opacity(0.72) : Color.white, in: Capsule())
        .shadow(color: .black.opacity(dark ? 0 : 0.08), radius: 4, y: 2)
    }
}

extension View {
    /// A rounded card with a thin darker edge underneath, like the buttons. Kept subtle on purpose:
    /// Habitract should feel like a habit app, not like an arcade.
    func ledgeCard(_ color: Color, ledge: Color? = nil, radius: CGFloat = 26, depth: CGFloat = 3) -> some View {
        let depth = min(depth, 3)
        return self
            .background(color, in: RoundedRectangle(cornerRadius: radius))
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(ledge ?? color.opacity(0.65))
                    .overlay(RoundedRectangle(cornerRadius: radius).fill(.black.opacity(0.10)))
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
    }
}

/// A white card with a big white title above it, for settings on the blue background.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.title(32))
                .foregroundStyle(.primary)
                .padding(.leading, 8)
            VStack(spacing: 0) { content }
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

/// One row in a settings card: title, small text, and a colored square icon on the right.
struct SettingsRow: View {
    let title: String
    var subtitle: String?
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.title(19))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer()
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(color, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: color.opacity(0.4), radius: 4, y: 3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
