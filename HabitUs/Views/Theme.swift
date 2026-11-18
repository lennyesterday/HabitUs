import SwiftUI
import HabitCore

// Colors, texts and small helpers shared by all screens. Area A.

enum Theme {
    static let cardBackground = Color(.secondarySystemBackground)

    /// The blue of the app icon.
    static let brand = Color(red: 0.012, green: 0.200, blue: 0.922)
    /// Warm yellow for the main buttons, the "fun" color next to the calm blue.
    static let sunshine = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let sunshineLedge = Color(red: 0.80, green: 0.58, blue: 0.10)
    static let brandLight = Color(red: 0.36, green: 0.48, blue: 1.0)

    /// Rounded, friendly title font used on onboarding and login.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    /// "14 Feb", always the Lisbon calendar day the database means.
    static func dayText(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        style.timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .current
        return date.formatted(style)
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

/// A big rounded button with a darker ledge underneath. It sinks in when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.sunshine
    var ledgeColor: Color = Theme.sunshineLedge
    var textColor: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        let ledge: CGFloat = 5
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(color, in: RoundedRectangle(cornerRadius: 16))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ledgeColor)
                    .offset(y: configuration.isPressed ? 0 : ledge)
            )
            .offset(y: configuration.isPressed ? ledge : 0)
            .padding(.bottom, ledge)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
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
