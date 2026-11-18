import SwiftUI
import PencilKit

// A white field to sign the contract with the finger (R4, R5). Area A.
// Always black ink on white, also in dark mode, so the saved PNG looks the same everywhere.

struct SignaturePad: View {
    @Binding var drawing: PKDrawing

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            CanvasView(drawing: $drawing)
                .frame(height: 160)
                .overlay(alignment: .bottomLeading) {
                    // The line people sign on, like on paper.
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 36)
                        .allowsHitTesting(false)
                }
                .overlay {
                    if drawing.strokes.isEmpty {
                        Text("Sign here with your finger")
                            .foregroundStyle(.gray)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4)))
            Button("Clear") { drawing = PKDrawing() }
                .font(.footnote)
                .disabled(drawing.strokes.isEmpty)
        }
    }

    /// The drawing as a small PNG with black ink, cut to the signature itself.
    static func png(from drawing: PKDrawing) -> Data? {
        guard !drawing.strokes.isEmpty else { return nil }
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: drawing.bounds.insetBy(dx: -10, dy: -10), scale: 1)
        }
        return image.pngData()
    }
}

private struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput           // finger and Apple Pencil
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.backgroundColor = .white
        canvas.overrideUserInterfaceStyle = .light // keep the ink black in dark mode
        canvas.isScrollEnabled = false
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let drawing: Binding<PKDrawing>

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvas: PKCanvasView) {
            drawing.wrappedValue = canvas.drawing
        }
    }
}

/// Shows a saved signature: the drawn image, or the typed text of older signatures.
struct SignatureImage: View {
    let signature: String

    var body: some View {
        if let png = SignatureFormat.png(from: signature), let image = UIImage(data: png) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 60)
                .padding(4)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
        } else {
            Text(signature)
                .italic()
        }
    }
}
