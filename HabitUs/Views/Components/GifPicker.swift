import SwiftUI

// Search GIPHY and pick a GIF for the chat (R26). Area B.

struct GifPicker: View {
    let onPick: (Gif) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var results: [Gif] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let errorMessage {
                    ErrorText(message: errorMessage)
                        .padding()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                    ForEach(results) { gif in
                        Button {
                            onPick(gif)
                        } label: {
                            AnimatedGif(url: gif.previewURL)
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal)
                if isLoading {
                    ProgressView().padding()
                }
            }
            .searchable(text: $term, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search GIPHY")
            .navigationTitle("GIFs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Required by GIPHY's terms wherever their search is shown.
                Text("Powered by GIPHY")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.bar)
            }
            // Searches half a second after the last key press, or shows trending GIFs.
            .task(id: term) {
                try? await Task.sleep(for: .milliseconds(term.isEmpty ? 0 : 500))
                guard !Task.isCancelled else { return }
                await search()
            }
        }
    }

    private func search() async {
        isLoading = true
        do {
            results = try await GifService.search(term)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// Shows a GIF from GIPHY with its animation. SwiftUI's Image cannot animate, so this wraps UIImageView.
struct AnimatedGif: View {
    let url: URL

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                AnimatedImageView(image: image)
                    .aspectRatio(image.size, contentMode: .fill)
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            } else {
                Rectangle()
                    .fill(Theme.cardBackground)
                    .overlay(ProgressView())
            }
        }
        .task(id: url) {
            do {
                image = try await GifService.loadImage(url)
            } catch {
                failed = true
            }
        }
    }
}

private struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        // Let SwiftUI decide the size instead of the GIF's own pixel size.
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.image = image
    }
}

#Preview {
    GifPicker { _ in }
}
