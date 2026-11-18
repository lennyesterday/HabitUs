import SwiftUI
import PhotosUI
import HabitCore

// The owner changes the group icon and the group picture. Area A.

struct GroupLookView: View {
    let group: HabitGroup
    let saved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var icon: String
    @State private var picture: UIImage?
    @State private var removePicture = false
    @State private var item: PhotosPickerItem?
    @State private var showEmojiPicker = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    init(group: HabitGroup, saved: @escaping () async -> Void) {
        self.group = group
        self.saved = saved
        _icon = State(initialValue: group.icon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Icon") {
                    Button {
                        showEmojiPicker = true
                    } label: {
                        HStack {
                            Text("Emoji")
                            Spacer()
                            Text(icon).font(.title)
                        }
                    }
                }

                Section {
                    PhotosPicker(selection: $item, matching: .images) {
                        Label(hasPicture ? "Change group picture" : "Add group picture", systemImage: "photo")
                    }
                    if hasPicture {
                        Button("Remove group picture", role: .destructive) {
                            picture = nil
                            removePicture = true
                        }
                    }
                } header: {
                    Text("Picture")
                } footer: {
                    Text("A picture replaces the emoji. Only members of the group can see it.")
                }

                if errorMessage != nil {
                    ErrorText(message: errorMessage)
                }
            }
            .disabled(isWorking)
            .navigationTitle("Group look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                    }
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPicker { icon = $0 }
            }
            .onChange(of: item) {
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        picture = image
                        removePicture = false
                    } else {
                        errorMessage = "This picture could not be opened."
                    }
                    self.item = nil
                }
            }
        }
    }

    private var hasPicture: Bool {
        picture != nil || (group.photoPath != nil && !removePicture)
    }

    @ViewBuilder
    private var preview: some View {
        if let picture {
            Image(uiImage: picture)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 25))
        } else {
            GroupBadge(icon: icon, path: removePicture ? nil : group.photoPath, size: 100)
        }
    }

    private func save() async {
        isWorking = true
        do {
            try await GroupService.updateLook(of: group, icon: icon, picture: picture,
                                              removePicture: removePicture)
            await saved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
