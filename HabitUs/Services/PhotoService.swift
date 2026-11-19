import UIKit
import HabitCore
import Supabase

// Upload and load proof photos in the private bucket "proofs" (R13, S8). Area B.

enum PhotoService {
    /// Photos already loaded, so the 10 second feed refresh does not download them again.
    private static let cache = NSCache<NSString, UIImage>()

    /// Resizes to at most 800 px, saves as JPEG (removes location data), uploads to
    /// <groupId>/<random uuid>.jpg and returns that path.
    static func upload(_ image: UIImage, groupId: UUID) async throws -> String {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > 800 ? 800 / longest : 1
        let size = CGSize(width: (image.size.width * scale).rounded(),
                          height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
            throw RuleError("Could not prepare the photo. Please try again.")
        }
        let path = "\(groupId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await readable {
            try await supabase.storage.from("proofs")
                .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
        }
        cache.setObject(resized, forKey: path as NSString)
        return path
    }

    /// Deletes every photo of a group (owner only, checked by the storage policy).
    static func deleteAll(groupId: UUID) async throws {
        let folder = groupId.uuidString.lowercased()
        try await readable {
            while true {
                let files = try await supabase.storage.from("proofs")
                    .list(path: folder, options: SearchOptions(limit: 100))
                guard !files.isEmpty else { break }
                let removed = try await supabase.storage.from("proofs")
                    .remove(paths: files.map { "\(folder)/\($0.name)" })
                // Stop if nothing could be deleted, instead of trying forever.
                if removed.isEmpty { break }
            }
        }
    }

    /// Loads a photo with the logged-in session. There are no public links (S8).
    static func load(path: String) async throws -> UIImage {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }
        return try await readable {
            let data = try await supabase.storage.from("proofs").download(path: path)
            guard let image = UIImage(data: data) else {
                throw RuleError("Could not show this photo.")
            }
            cache.setObject(image, forKey: path as NSString)
            return image
        }
    }
}
