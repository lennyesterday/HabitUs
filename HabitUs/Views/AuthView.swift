import SwiftUI

// Landing, sign up and log in (R1 to R3). Area A.

struct AuthView: View {
    private enum Mode: String, CaseIterable {
        case logIn = "Log in"
        case signUp = "Sign up"
    }

    @State private var mode = Mode.logIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var acceptedTerms = false
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HabitUs")
                        .font(.largeTitle.bold())
                    Label("Pick a habit with your friends and sign the contract.", systemImage: "signature")
                    Label("Prove every task with a live photo.", systemImage: "camera")
                    Label("The group checks, the leaderboard shows who delivers.", systemImage: "trophy")
                }
                .font(.subheadline)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(mode == .signUp ? "Password (at least 8 characters)" : "Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                    if mode == .signUp {
                        TextField("Display name (2 to 20 characters)", text: $displayName)
                            .textContentType(.nickname)
                    }
                }
                .textFieldStyle(.roundedBorder)

                if mode == .signUp {
                    Toggle("I agree that my proof photos are visible to the members of my groups.",
                           isOn: $acceptedTerms)
                        .font(.footnote)
                }

                ErrorText(message: errorMessage)

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking)
            }
            .padding()
        }
        .onChange(of: mode) { errorMessage = nil }
    }

    private func submit() async {
        isWorking = true
        errorMessage = nil
        do {
            if mode == .signUp {
                try await AuthService.signUp(email: email, password: password, displayName: displayName,
                                             acceptedTerms: acceptedTerms)
            } else {
                try await AuthService.logIn(email: email, password: password)
            }
            // RootView switches to Home by itself once the login is there.
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}

#Preview {
    AuthView()
}
