import SwiftUI
import HabitCore

// Landing, sign up and log in (R1 to R3). Area A.

struct AuthView: View {
    private enum Mode: String, CaseIterable {
        case logIn = "Log in"
        case signUp = "Sign up"
    }

    @State private var mode = Mode.logIn
    @State private var email = ""
    @State private var password = ""
    @State private var passwordAgain = ""
    @State private var displayName = ""
    @State private var acceptedTerms = false
    @State private var errorMessage: String?
    @State private var isWorking = false
    /// Set when Supabase emailed a confirmation code: the card then asks for the code.
    @State private var codeEmail: String?
    @State private var code = ""
    @State private var infoMessage: String?
    /// Set while "Forgot password?" is open: first the email, then the code and a new password.
    @State private var reset: ResetStep?
    @State private var newPassword = ""
    @State private var newPasswordAgain = ""
    @FocusState private var focused: Field?

    private enum Field {
        case email, password, passwordAgain, name, newPassword, newPasswordAgain
    }

    private enum ResetStep: Equatable {
        case askEmail
        case enterCode(String)
    }

    var body: some View {
        ZStack {
            HomeBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image("Logo")
                            .resizable()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                        Text("Habitract")
                            .font(Theme.title(40))
                            .foregroundStyle(.primary)
                        Text(mode == .logIn ? "Welcome back! Your group is waiting."
                                            : "Create your account and start a streak.")
                            .font(.system(.body, design: .default))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 14) {
                        if let codeEmail {
                            codeEntry(codeEmail)
                        } else if let reset {
                            resetCard(reset)
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
                            SecureField("Password", text: $password)
                                .textContentType(mode == .signUp ? .newPassword : .password)
                        }
                        if mode == .signUp {
                            field(.passwordAgain) {
                                SecureField("Repeat password", text: $passwordAgain)
                                    .textContentType(.newPassword)
                            }
                            PasswordChecklist(password: password, repeated: passwordAgain)
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

                        if mode == .logIn {
                            Button("Forgot password?") {
                                errorMessage = nil
                                withAnimation { reset = .askEmail }
                            }
                            .font(.system(.subheadline, design: .default).weight(.semibold))
                        }
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
                        .font(.system(.subheadline, design: .default).weight(.semibold))
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
                                                             repeatedPassword: passwordAgain,
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

    /// `signUp`, `codeEmail` and `resetEmail` are only set by the previews, to show those screens without a real email.
    init(signUp: Bool = false, codeEmail: String? = nil, resetEmail: String? = nil) {
        _mode = State(initialValue: signUp ? .signUp : .logIn)
        _codeEmail = State(initialValue: codeEmail)
        _reset = State(initialValue: resetEmail.map { .enterCode($0) })
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
                .foregroundStyle(.primary)
            Text("Check your email")
                .font(Theme.title(24))
                .foregroundStyle(.primary)
            Text("We sent a code to **\(address)**. Enter it here to finish.")
                .font(.system(.subheadline, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            codeField

            ErrorText(message: errorMessage)
            InfoText(message: infoMessage)

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
            .font(.system(.subheadline, design: .default).weight(.semibold))
        }
    }

    /// The big field for the 6 digit code from an email. Only digits can be typed.
    private var codeField: some View {
        TextField("123456", text: $code)
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 30, weight: .bold, design: .monospaced))
            .padding(.vertical, 10)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: code) { code = String(code.filter(\.isNumber).prefix(10)) }
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

    // MARK: - Forgot password

    @ViewBuilder
    private func resetCard(_ step: ResetStep) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.primary)

            switch step {
            case .askEmail:
                Text("Forgot your password?")
                    .font(Theme.title(24))
                    .foregroundStyle(.primary)
                Text("Enter your email. We send you a code to set a new password.")
                    .font(.system(.subheadline, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                field(.email) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                ErrorText(message: errorMessage)

                Button {
                    Task { await sendResetCode() }
                } label: {
                    if isWorking { ProgressView().tint(.black) } else { Text("Send code") }
                }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(isWorking)

            case .enterCode(let address):
                Text("Check your email")
                    .font(Theme.title(24))
                    .foregroundStyle(.primary)
                Text("If there is an account for **\(address)**, we sent it a code. Enter it and choose a new password.")
                    .font(.system(.subheadline, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                codeField
                field(.newPassword) {
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                }
                field(.newPasswordAgain) {
                    SecureField("Repeat new password", text: $newPasswordAgain)
                        .textContentType(.newPassword)
                }
                PasswordChecklist(password: newPassword, repeated: newPasswordAgain)

                ErrorText(message: errorMessage)
                InfoText(message: infoMessage)

                Button {
                    Task { await saveNewPassword(address) }
                } label: {
                    if isWorking { ProgressView().tint(.black) } else { Text("Save new password") }
                }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(isWorking || code.count < 6)
            }

            HStack {
                Button("Back") {
                    errorMessage = nil
                    infoMessage = nil
                    withAnimation { reset = nil }
                }
                Spacer()
                if case .enterCode = step {
                    Button("Send a new code") {
                        Task { await sendResetCode() }
                    }
                    .disabled(isWorking)
                }
            }
            .font(.system(.subheadline, design: .default).weight(.semibold))
        }
    }

    private func sendResetCode() async {
        isWorking = true
        errorMessage = nil
        do {
            try await AuthService.sendResetCode(email: email)
            if reset == .askEmail {
                code = ""
                newPassword = ""
                newPasswordAgain = ""
                infoMessage = nil
                withAnimation { reset = .enterCode(email.trimmingCharacters(in: .whitespaces)) }
            } else {
                infoMessage = "A new code is on its way. Check your spam folder too."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func saveNewPassword(_ address: String) async {
        isWorking = true
        errorMessage = nil
        do {
            try await AuthService.setNewPassword(email: address, code: code, password: newPassword,
                                                 repeatedPassword: newPasswordAgain)
            // Logged in with the new password now: RootView switches to Home by itself.
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}

/// The password rules from HabitCore as a live checklist, plus "Both passwords match".
/// Each line turns green with a tick as soon as it is met.
private struct PasswordChecklist: View {
    let password: String
    let repeated: String

    var body: some View {
        let rules = passwordRules(password)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rules, id: \.text) { rule in
                line(rule.text, isMet: rule.isMet)
            }
            line("Both passwords match", isMet: !repeated.isEmpty && password == repeated)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .animation(.snappy, value: password)
        .animation(.snappy, value: repeated)
    }

    private func line(_ text: String, isMet: Bool) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? Color.green : Color.secondary)
        }
        .font(.system(.footnote, design: .default))
        .foregroundStyle(isMet ? Color.primary : Color.secondary)
        .accessibilityLabel("\(text): \(isMet ? "done" : "missing")")
    }
}

/// A grey hint under a form, for example "A new code is on its way".
private struct InfoText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Log in") {
    AuthView()
}

#Preview("Sign up") {
    AuthView(signUp: true)
}

#Preview("Code from email") {
    AuthView(codeEmail: "lenny@example.com")
}

#Preview("Forgot password") {
    AuthView(resetEmail: "lenny@example.com")
}
