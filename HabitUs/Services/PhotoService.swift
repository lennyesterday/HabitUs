import UIKit
import Supabase

// Upload and load proof photos in the private bucket "proofs" (R13, S8). Area B.
// STUBS: replace each body with the real Supabase call.

enum PhotoService {
    /// Resizes to at most 800 px, saves as JPEG (removes location data), uploads to
    /// <groupId>/<random uuid>.jpg and returns that path.
    static func upload(_ image: UIImage, groupId: UUID) async throws -> String {
        throw notBuiltYet
    }

    static func load(path: String) async throws -> UIImage {
        throw notBuiltYet
    }
}
