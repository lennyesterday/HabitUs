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
    /// Set when Supabase emailed a confirmation code: the card then asks for the code.
    @State private var codeEmail: String?
    @State private var code = ""
    @State private var infoMessage: String?
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
                        if let codeEmail {
                            codeEntry(codeEmail)
                        } else {
                        modeSwitch

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

    /// Two buttons to switch between log in and sign up. A plain segmented Picker changed its
    /// value by itself when the simulator used the Mac keyboard, so this one only reacts to taps.
    private var modeSwitch: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases, id: \.self) { option in
                Button {
                    withAnimation(.snappy) { mode = option }
                } label: {
                    Text(option.rawValue)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(mode == option ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if mode == option {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 13))
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
                let needsCode = try await AuthService.signUp(email: email, password: password,
                                                             displayName: displayName, acceptedTerms: acceptedTerms)
                if needsCode { showCodeEntry() }
            } else {
                try await AuthService.logIn(email: email, password: password)
            }
            // RootView switches to Home by itself once the login is there.
        } catch is EmailNotConfirmed {
            showCodeEntry()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    /// `codeEmail` is only set by the preview, to show the code screen without a real email.
    init(codeEmail: String? = nil) {
        _codeEmail = State(initialValue: codeEmail)
    }

    private func showCodeEntry() {
        code = ""
        infoMessage = nil
        withAnimation { codeEmail = email.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Confirmation code (only when "Confirm email" is on in Supabase)

    private func codeEntry(_ address: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.brand)
            Text("Check your email")
                .font(Theme.title(24))
                .foregroundStyle(Theme.ink)
            Text("We sent a code to **\(address)**. Enter it here to finish.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("123456", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .padding(.vertical, 10)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: code) { code = String(code.filter(\.isNumber).prefix(10)) }

            ErrorText(message: errorMessage)
            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await confirm(address) }
            } label: {
                if isWorking { ProgressView().tint(.black) } else { Text("Confirm") }
            }
            .buttonStyle(ChunkyButtonStyle())
            .disabled(isWorking || code.count < 6)

            HStack {
                Button("Back") {
                    withAnimation { codeEmail = nil }
                    errorMessage = nil
                }
                Spacer()
                Button("Send a new code") {
                    Task { await resend(address) }
                }
                .disabled(isWorking)
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
    }

    private func confirm(_ address: String) async {
        isWorking = true
        errorMessage = nil
        do {
            try await AuthService.verifyEmailCode(email: address, code: code)
            // Logged in now: RootView switches to Home by itself.
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func resend(_ address: String) async {
        isWorking = true
        errorMessage = nil
        do {
            try await AuthService.resendEmailCode(email: address)
            infoMessage = "A new code is on its way. Check your spam folder too."
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}

#Preview("Log in") {
    AuthView()
}

#Preview("Code from email") {
    AuthView(codeEmail: "lenny@example.com")
}
