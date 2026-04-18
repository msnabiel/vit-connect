import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthenticationViewModel
    @State private var captchaInput: String = ""
    @FocusState private var focusedField: Field?
    @State private var showPassword: Bool = false
    @State private var rememberMe: Bool = true
    @State private var shakeOffset: CGFloat = 0
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false

    enum Field {
        case username, password
    }

    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Login")
                                    .font(.system(size: 48, weight: .bold, design: .default))
                                    .foregroundColor(.primary)

                                Text("Sign in using your VTOP credentials")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.top, 80)
                    .padding(.bottom, 60)

                    // Login Form
                    VStack(spacing: 20) {
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)

                                TextField("Username", text: $viewModel.username)
                                    .font(.system(size: 17))
                                    .autocapitalization(.allCharacters)
                                    .disableAutocorrection(true)
                                    .textContentType(.username)
                                    .focused($focusedField, equals: .username)
                                    .disabled(viewModel.isLoading)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        focusedField == .username ? Color.accentColor : Color.clear,
                                        lineWidth: 2
                                    )
                            )

                            // Username hint
                            Text("Note: Username may not be your registration number")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.leading, 4)
                        }

                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)

                                Group {
                                    if showPassword {
                                        TextField("Password", text: $viewModel.password)
                                            .font(.system(size: 17))
                                            .textContentType(.password)
                                            .focused($focusedField, equals: .password)
                                            .disabled(viewModel.isLoading)
                                            .submitLabel(.go)
                                            .onSubmit {
                                                if !viewModel.username.isEmpty && !viewModel.password.isEmpty {
                                                    handleSignIn()
                                                }
                                            }
                                    } else {
                                        SecureField("Password", text: $viewModel.password)
                                            .font(.system(size: 17))
                                            .textContentType(.password)
                                            .focused($focusedField, equals: .password)
                                            .disabled(viewModel.isLoading)
                                            .submitLabel(.go)
                                            .onSubmit {
                                                if !viewModel.username.isEmpty && !viewModel.password.isEmpty {
                                                    handleSignIn()
                                                }
                                            }
                                    }
                                }

                                // Eye icon toggle
                                Button(action: {
                                    showPassword.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                                .disabled(viewModel.isLoading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        focusedField == .password ? Color.accentColor : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }

                        // Remember Me Toggle
                        HStack {
                            Toggle(isOn: $rememberMe) {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(rememberMe ? .accentColor : .secondary)

                                    Text("Remember me")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            .toggleStyle(.button)
                            .buttonStyle(.plain)

                            Spacer()

                            // Biometric authentication button
                            if biometricAvailable() {
                                Button(action: authenticateWithBiometric) {
                                    HStack(spacing: 6) {
                                        Image(systemName: biometricType() == .faceID ? "faceid" : "touchid")
                                            .font(.system(size: 16))
                                        Text("Use \(biometricType() == .faceID ? "Face ID" : "Touch ID")")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.accentColor)
                                }
                                .disabled(viewModel.isLoading)
                            }
                        }
                        .padding(.vertical, 4)

                        // Error Message with shake animation
                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .offset(x: shakeOffset)
                            .onAppear {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                                    shakeAnimation()
                                }
                            }
                        }

                        // Sign In Button
                        Button(action: {
                            handleSignIn()
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.loginSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                } else if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                }

                                Text(viewModel.loginSuccess ? "LOGIN SUCCESSFUL!" : (viewModel.isLoading ? "SIGNING IN..." : "SIGN IN"))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        viewModel.loginSuccess ? Color.green :
                                        (viewModel.isLoading || viewModel.username.isEmpty || viewModel.password.isEmpty
                                        ? Color.accentColor.opacity(0.5)
                                        : Color.accentColor)
                                    )
                            )
                            .shadow(
                                color: viewModel.loginSuccess ? Color.green.opacity(0.3) : Color.accentColor.opacity(0.3),
                                radius: 8, x: 0, y: 4
                            )
                        }
                        .disabled(viewModel.isLoading || viewModel.username.isEmpty || viewModel.password.isEmpty)
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 40)

                    // Privacy Policy Link
                    Button(action: {
                        if let url = URL(string: "https://vtopcc.vit.ac.in") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Privacy Policy")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $viewModel.showCaptcha) {
            CaptchaInputView(
                captchaImage: viewModel.captchaImage,
                captchaInput: $captchaInput,
                onSubmit: {
                    viewModel.submitLogin(captchaText: captchaInput)
                    captchaInput = ""
                },
                onCancel: {
                    viewModel.showCaptcha = false
                    viewModel.isLoading = false
                }
            )
            .presentationDetents([.height(320), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showReCaptchaWebView) {
            if let webView = viewModel.getWebView() {
                ReCaptchaView(webView: webView, isPresented: $viewModel.showReCaptchaWebView)
            }
        }
    }

    // MARK: - Helper Functions

    private func handleSignIn() {
        focusedField = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Uppercase username
        viewModel.username = viewModel.username.uppercased()

        // Save remember me preference
        viewModel.rememberMe = rememberMe

        viewModel.signIn()
    }

    private func shakeAnimation() {
        let animation = Animation.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0)
        withAnimation(animation) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(animation) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(animation) {
                shakeOffset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(animation) {
                shakeOffset = 0
            }
        }

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func biometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private func biometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    private func authenticateWithBiometric() {
        let context = LAContext()
        let reason = "Authenticate to sign in to VTOP"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Auto-fill credentials if saved
                    if let savedUsername = KeychainHelper.shared.getUsername(),
                       let savedPassword = KeychainHelper.shared.getPassword() {
                        viewModel.username = savedUsername
                        viewModel.password = savedPassword

                        // Auto sign in after biometric success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            handleSignIn()
                        }
                    }
                } else {
                    if let error = error {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationViewModel())
}
