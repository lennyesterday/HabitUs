import SwiftUI
import HabitCore

// Pause with a reason instead of a photo (R18). Area B.
// The sheet only collects the reason. GroupView posts it through CheckinService.

struct PauseSheet: View {
    let habit: String
    /// Posts the pause. Throws a RuleError with a readable text if it did not work.
    let onPost: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var errorMessage: String?
    @State private var isPosting = false

    private let maxLength = 200

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Can't do \(habit) today, for example because you are sick? Tell the group why.")
                    .font(.system(.body, design: .default))

                VStack(alignment: .trailing, spacing: 4) {
                    TextField("Reason", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                        // R18: at most 200 characters.
                        .onChange(of: reason) {
                            if reason.count > maxLength { reason = String(reason.prefix(maxLength)) }
                        }
                    Text("\(reason.count)/\(maxLength)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Label("The pause counts as done with full points. If more than half of the others press 👎 within 48 hours, the points are gone and this task cannot be redone.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ErrorText(message: errorMessage)

                Button {
                    Task { await post() }
                } label: {
                    if isPosting {
                        ProgressView().tint(.black)
                    } else {
                        Label("Post pause", systemImage: "pause.circle.fill")
                    }
                }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(isPosting)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Take a pause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func post() async {
        do {
            try validatePauseReason(reason)
            isPosting = true
            try await onPost(reason)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }
}

#Preview {
    PauseSheet(habit: "Gym") { _ in }
}
