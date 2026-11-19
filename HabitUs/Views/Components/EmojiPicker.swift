import SwiftUI
import HabitCore

// Pick one of all emojis as the group icon, with search by English name (R4). Area A.
// iOS has no emoji picker for apps, so the list is built from the Unicode emoji properties.

struct EmojiPicker: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
                    ForEach(results, id: \.emoji) { entry in
                        Button(entry.emoji) {
                            onPick(entry.emoji)
                            dismiss()
                        }
                        .font(.system(size: 32))
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(entry.name)
                    }
                }
                .padding(.horizontal)
                if results.isEmpty {
                    Text("No emoji found.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search, for example dumbbell")
            .navigationTitle("Group icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var results: [EmojiCatalog.Entry] {
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return EmojiCatalog.all }
        return EmojiCatalog.all.filter { $0.name.contains(term) }
    }
}

enum EmojiCatalog {
    struct Entry {
        let emoji: String
        let name: String
    }

    /// Faces first, then people, nature, food, activities, travel, objects and symbols.
    private static let ranges: [ClosedRange<UInt32>] = [
        0x1F600...0x1F64F, 0x1F910...0x1F9FF, 0x1F300...0x1F5FF,
        0x1F680...0x1F6FF, 0x1FA70...0x1FAFF, 0x2600...0x27BF,
    ]

    /// About 1300 emojis, built once when the picker is opened the first time.
    static let all: [Entry] = ranges.flatMap { range in
        range.compactMap { value -> Entry? in
            guard let scalar = Unicode.Scalar(value),
                  scalar.properties.isEmoji,
                  !scalar.properties.isEmojiModifier else { return nil }
            // Some emojis only look like emojis with the emoji style marker U+FE0F.
            let emoji = scalar.properties.isEmojiPresentation
                ? String(scalar)
                : String(scalar) + "\u{FE0F}"
            guard (try? validateGroupIcon(emoji)) != nil else { return nil }
            return Entry(emoji: emoji, name: scalar.properties.name?.lowercased() ?? "")
        }
    }
}

#Preview {
    EmojiPicker { _ in }
}
