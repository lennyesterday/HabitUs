import SwiftUI
import HabitCore

// Colors, texts and small helpers shared by all screens. Area A.

enum Theme {
    static let cardBackground = Color(.secondarySystemBackground)

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
