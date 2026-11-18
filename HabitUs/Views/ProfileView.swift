import SwiftUI
import PhotosUI

// My profile: name, profile picture, log out. Area A.

struct ProfileView: View {
    @Binding var profile: Profile?

    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        ProfilePicture(name: profile?.displayName ?? "?", path: profile?.photoPath, size: 120)
                            .overlay {
                                if isWorking { ProgressView() }
                            }
                        Text(profile?.displayName ?? "")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    PhotosPicker(selection: $item, matching: .images) {
                        Label(profile?.photoPath == nil ? "Add profile picture" : "Change profile picture",
                              systemImage: "photo")
                    }
                    if profile?.photoPath != nil {
                        Button("Remove profile picture", role: .destructive) {
                            Task { await save(nil) }
                        }
                    }
                } footer: {
                    Text("Every HabitUs user can see your name and profile picture.")
                }

                if errorMessage != nil {
                    ErrorText(message: errorMessage)
                }

                Section {
                    Button("Log out", role: .destructive) {
                        Task { try? await AuthService.logOut() }
                    }
                }
            }
            .disabled(isWorking)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: item) {
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await save(image)
                    } else {
                        errorMessage = "This picture could not be opened."
                    }
                    self.item = nil
                }
            }
        }
    }

    private func save(_ image: UIImage?) async {
        isWorking = true
        do {
            profile = try await AuthService.setProfilePicture(image)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
