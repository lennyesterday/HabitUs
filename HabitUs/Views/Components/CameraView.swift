import SwiftUI
import UIKit

// Camera only, no photo library (R13). Area B.
// The simulator has no camera. There, a test photo can be made instead (simulator builds only).

struct CameraView: View {
    let onPhoto: (UIImage) -> Void

    var body: some View {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            CameraPicker(onPhoto: onPhoto)
        } else {
            NoCameraView(onPhoto: onPhoto)
        }
    }
}

/// UIImagePickerController with source `.camera`. There is no way to pick from the library.
private struct CameraPicker: UIViewControllerRepresentable {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPhoto(image)
            } else {
                parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private struct NoCameraView: View {
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 48))
            Text("No camera on this device")
                .font(.title3.bold())
            #if targetEnvironment(simulator)
            Text("The simulator has no camera. For testing you can send a generated test photo.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Use test photo") { onPhoto(Self.testPhoto()) }
                .buttonStyle(.borderedProminent)
            #endif
            Button("Cancel") { dismiss() }
        }
        .padding()
    }

    #if targetEnvironment(simulator)
    /// A colored picture with the time on it, so every test photo looks different.
    static func testPhoto() -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hue: .random(in: 0...1), saturation: 0.5, brightness: 0.9, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let text = "Test photo\n\(Date().formatted(date: .abbreviated, time: .shortened))" as NSString
            text.draw(in: CGRect(x: 80, y: 340, width: 1040, height: 300),
                      withAttributes: [.font: UIFont.boldSystemFont(ofSize: 90), .foregroundColor: UIColor.white])
        }
    }
    #endif
}
