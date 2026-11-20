import SwiftUI
import PhotosUI

// My profile and settings: picture, how it works, log out, info. Area A.
// Tap the round picture to take a new photo, pick one from the library, or remove it.
// Big white section cards on the blue background, like the settings of the inspiration.

struct ProfileView: View {
    @Binding var profile: Profile?

    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showOnboarding = false
    @State private var confirmLogOut = false
    @State private var showPictureOptions = false
    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            BrandBackground()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Button {
                            showPictureOptions = true
                        } label: {
                            ProfilePicture(name: profile?.displayName ?? "?", path: profile?.photoPath, size: 120)
                                .overlay(Circle().stroke(.white, lineWidth: 5))
                                .overlay { if isWorking { ProgressView().tint(.white) } }
                                .overlay(alignment: .bottomTrailing) {
                                    // Small camera badge, so people see that the picture can be changed.
                                    Image(systemName: "camera.fill")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Theme.brand)
                                        .frame(width: 36, height: 36)
                                        .background(.white, in: Circle())
                                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                        .offset(x: 2, y: 2)
                                }
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
                        }
                        .buttonStyle(PressableCardStyle())
                        .disabled(isWorking)
                        .accessibilityLabel("Profile picture")
                        .accessibilityHint("Take a photo, choose one from the library, or remove it")
                        Text(profile?.displayName ?? "")
                            .font(Theme.title(32))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 50)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.bold())
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                    }

                    SettingsSection(title: "Help") {
                        Button { showOnboarding = true } label: {
                            SettingsRow(title: "How it works", subtitle: "The rules of HabitUs in five pages.",
                                        symbol: "questionmark", color: Theme.rankColor(3))
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.horizontal, 20)
                        SettingsRow(title: "Points", subtitle: "20 per task, +25 % for a full round, +5 % per round in a row, max +50 %.",
                                    symbol: "flame.fill", color: Theme.rankColor(4))
                    }

                    SettingsSection(title: "Account") {
                        Button { confirmLogOut = true } label: {
                            SettingsRow(title: "Log out", symbol: "rectangle.portrait.and.arrow.right",
                                        color: Theme.rankColor(0))
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Info") {
                        SettingsRow(title: "Version \(appVersion)", symbol: "info", color: Color(white: 0.35))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }

            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Close")
            .padding(.leading, 18)
            .padding(.top, 8)
        }
        .disabled(isWorking)
        .confirmationDialog("Log out?", isPresented: $confirmLogOut, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                Task { try? await AuthService.logOut() }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { showOnboarding = false }
        }
        .confirmationDialog("Profile picture", isPresented: $showPictureOptions, titleVisibility: .visible) {
            Button("Take photo") { showCamera = true }
            Button("Choose from library") { showLibrary = true }
            if profile?.photoPath != nil {
                Button("Remove picture", role: .destructive) { Task { await save(nil) } }
            }
        } message: {
            Text("Every HabitUs user can see your picture, like your name.")
        }
        .photosPicker(isPresented: $showLibrary, selection: $item, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                showCamera = false
                Task { await save(image) }
            }
            .ignoresSafeArea()
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

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
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

#Preview {
    ProfileView(profile: .constant(Profile(displayName: "Lenny", photoPath: nil)))
}
