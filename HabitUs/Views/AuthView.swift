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
    @FocusState private var focused: Field?

    private enum Field {
        case email, password, name
    }

    var body: some View {
        ZStack {
            BrandBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image("Logo")
                            .resizable()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                        Text("HabitUs")
                            .font(Theme.title(40))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.2), radius: 0, y: 3)
                        Text(mode == .logIn ? "Welcome back! Your group is waiting."
                                            : "Create your account and start a streak.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 14) {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)

                        field(.email) {
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        field(.password) {
                            SecureField(mode == .signUp ? "Password (at least 8 characters)" : "Password",
                                        text: $password)
                                .textContentType(mode == .signUp ? .newPassword : .password)
                        }
                        if mode == .signUp {
                            field(.name) {
                                TextField("Display name (2 to 20 characters)", text: $displayName)
                                    .textContentType(.nickname)
                            }
                            Toggle("I agree that my proof photos are visible to the members of my groups.",
                                   isOn: $acceptedTerms)
                                .font(.footnote)
                                .tint(Theme.brand)
                        }

                        ErrorText(message: errorMessage)

                        Button {
                            Task { await submit() }
                        } label: {
                            if isWorking {
                                ProgressView().tint(.black)
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle())
                        .disabled(isWorking)
                    }
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: mode) { errorMessage = nil }
    }

    /// A soft grey rounded box around a text field. Tapping anywhere in the box puts the
    /// cursor into the field, not only on the thin line of text in the middle.
    private func field(_ which: Field, @ViewBuilder _ content: () -> some View) -> some View {
        content()
            .focused($focused, equals: which)
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture { focused = which }
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
