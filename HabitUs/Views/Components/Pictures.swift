import SwiftUI
import HabitCore

// Round profile pictures and group badges. Area A.

/// A profile picture, or the first letter of the name when there is none.
struct ProfilePicture: View {
    let name: String
    let path: String?
    var size: CGFloat = 32

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(name.prefix(1).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.avatarColor(name).gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: path) {
            image = nil
            if let path {
                image = try? await PictureService.load(path: path)
            }
        }
    }
}

/// The group picture, or its emoji icon when there is none.
struct GroupBadge: View {
    let icon: String
    let path: String?
    var size: CGFloat = 40

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(icon)
                    .font(.system(size: size * 0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.cardBackground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
        .accessibilityHidden(true)
        .task(id: path) {
            image = nil
            if let path {
                image = try? await PictureService.load(path: path)
            }
        }
    }
}

extension GroupBadge {
    init(group: HabitGroup, size: CGFloat = 40) {
        self.init(icon: group.icon, path: group.photoPath, size: size)
    }
}
