import UIKit
import HabitCore
import Supabase

// Profile pictures and group pictures in the private bucket "pictures". Area A.
// Unlike proof photos these may come from the photo library.

enum PictureService {
    private static let bucket = "pictures"
    private static let cache = NSCache<NSString, UIImage>()

    /// Crops to a square, resizes to 400 px, saves as JPEG (removes location data) and uploads
    /// to <folder>/<random uuid>.jpg. Returns the path.
    static func upload(_ image: UIImage, folder: String) async throws -> String {
        let side = min(image.size.width, image.size.height)
        let size = CGSize(width: 400, height: 400)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // Draw the image so that its center square fills the 400 x 400 picture.
            let scale = 400 / side
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (400 - drawSize.width) / 2, y: (400 - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        guard let jpeg = square.jpegData(compressionQuality: 0.8) else {
            throw RuleError("Could not prepare the picture. Please try another one.")
        }
        let path = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
        try await readable {
            try await supabase.storage.from(bucket)
                .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
        }
        cache.setObject(square, forKey: path as NSString)
        return path
    }

    static func load(path: String) async throws -> UIImage {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }
        return try await readable {
            let data = try await supabase.storage.from(bucket).download(path: path)
            guard let image = UIImage(data: data) else {
                throw RuleError("Could not show this picture.")
            }
            cache.setObject(image, forKey: path as NSString)
            return image
        }
    }

    /// Deletes a picture that is no longer used. Errors are ignored: a left-over file only costs space.
    static func deleteQuietly(path: String?) async {
        guard let path else { return }
        _ = try? await supabase.storage.from(bucket).remove(paths: [path])
    }

    /// Deletes all pictures of a group, when the group is deleted.
    static func deleteAll(groupId: UUID) async {
        let folder = "groups/\(groupId.uuidString.lowercased())"
        guard let files = try? await supabase.storage.from(bucket).list(path: folder) else { return }
        _ = try? await supabase.storage.from(bucket).remove(paths: files.map { "\(folder)/\($0.name)" })
    }
}
