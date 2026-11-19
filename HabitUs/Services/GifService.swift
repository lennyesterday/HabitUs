import UIKit
import ImageIO
import HabitCore

// GIF search on GIPHY and loading of animated GIFs for the chat (R26). Area B.
// Search terms go to GIPHY. Only GIFs rated G (suitable for everyone) are shown.
// GIPHY's terms ask for a visible "Powered by GIPHY" wherever the search is shown.

/// One search result.
struct Gif: Identifiable, Hashable {
    var id: String
    /// Small version for the search grid.
    var previewURL: URL
    /// The version that is sent into the chat (200 px wide).
    var url: URL
}

private struct GiphyResponse: Decodable {
    struct Item: Decodable {
        struct Images: Decodable {
            struct Rendition: Decodable {
                let url: String?
            }
            let fixed_width: Rendition
            let fixed_width_small: Rendition
        }
        let id: String
        let images: Images
    }
    let data: [Item]
}

enum GifService {
    private static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GIPHY_API_KEY") as? String,
              !key.isEmpty, key != "DEIN_GIPHY_KEY" else { return nil }
        return key
    }

    /// False until GIPHY_API_KEY is filled in Config/Secrets.xcconfig. The GIF button then says so.
    static var isConfigured: Bool { apiKey != nil }

    /// GIFs for a search term, or the trending ones when the term is empty.
    static func search(_ term: String) async throws -> [Gif] {
        guard let apiKey else {
            throw RuleError("GIF search is not set up. Add GIPHY_API_KEY to Config/Secrets.xcconfig.")
        }
        let term = term.trimmingCharacters(in: .whitespaces)
        var components = URLComponents(string: term.isEmpty
                                       ? "https://api.giphy.com/v1/gifs/trending"
                                       : "https://api.giphy.com/v1/gifs/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "limit", value: "24"),
            URLQueryItem(name: "rating", value: "g"),
        ]
        guard let url = components?.url else {
            throw RuleError("Could not search for GIFs.")
        }
        return try await readable {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw RuleError("GIPHY did not answer. Check the GIPHY key and try again.")
            }
            let items = try JSONDecoder().decode(GiphyResponse.self, from: data).data
            // Keep only results whose links pass the same rule the database checks.
            return items.compactMap { item in
                guard let full = item.images.fixed_width.url,
                      (try? validateGifURL(full)) != nil,
                      let url = URL(string: full) else { return nil }
                let preview = item.images.fixed_width_small.url.flatMap(URL.init(string:)) ?? url
                return Gif(id: item.id, previewURL: preview, url: url)
            }
        }
    }

    /// GIFs already loaded, so the 10 second feed refresh does not download them again.
    private static let cache = NSCache<NSURL, UIImage>()

    /// Downloads a GIF and turns all its frames into one animated image.
    static func loadImage(_ url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        return try await readable {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = animatedImage(from: data) else {
                throw RuleError("Could not show this GIF.")
            }
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
    }

    /// Reads every frame and its delay from the GIF file.
    private static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: frame))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            duration += delay < 0.02 ? 0.1 : delay
        }
        guard frames.count > 1 else { return frames.first }
        return UIImage.animatedImage(with: frames, duration: duration)
    }
}
