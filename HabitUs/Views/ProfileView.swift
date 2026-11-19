import SwiftUI
import PhotosUI

// My profile and settings: picture, how it works, log out, info. Area A.
// Big white section cards on the blue background, like the settings of the inspiration.

struct ProfileView: View {
    @Binding var profile: Profile?

    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showOnboarding = false
    @State private var confirmLogOut = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            BrandBackground()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        ProfilePicture(name: profile?.displayName ?? "?", path: profile?.photoPath, size: 120)
                            .overlay(Circle().stroke(.white, lineWidth: 5))
                            .overlay { if isWorking { ProgressView().tint(.white) } }
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
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

                    SettingsSection(title: "Profile") {
                        PhotosPicker(selection: $item, matching: .images) {
                            SettingsRow(title: profile?.photoPath == nil ? "Add picture" : "Change picture",
                                        subtitle: "Every HabitUs user can see it, like your name.",
                                        symbol: "camera.fill", color: Theme.rankColor(2))
                        }
                        .buttonStyle(.plain)
                        if profile?.photoPath != nil {
                            Divider().padding(.horizontal, 20)
                            Button { Task { await save(nil) } } label: {
                                SettingsRow(title: "Remove picture", symbol: "trash.fill", color: Theme.rankColor(0))
                            }
                            .buttonStyle(.plain)
                        }
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
                        Divider().padding(.horizontal, 20)
                        SettingsRow(title: "HabitUs, 2026", subtitle: "Nova SBE · Introduction to Programming",
                                    symbol: "c.circle", color: Color(white: 0.35))
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
