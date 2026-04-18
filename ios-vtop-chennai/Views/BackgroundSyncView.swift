import SwiftUI

struct BackgroundSyncView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var captchaText: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if authViewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Refreshing data...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if authViewModel.showCaptcha, let captchaImage = authViewModel.captchaImage {
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Verification Required")
                                .font(.system(size: 24, weight: .bold))

                            Text("Please enter the captcha to continue syncing")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            // Captcha image
                            Image(uiImage: captchaImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )

                            // Captcha input
                            TextField("Enter Captcha", text: $captchaText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal, 40)

                            Button(action: {
                                authViewModel.submitLogin(captchaText: captchaText)
                                captchaText = ""
                            }) {
                                Text("Submit")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(captchaText.isEmpty ? Color.gray : Color.accentColor)
                                    )
                            }
                            .disabled(captchaText.isEmpty)
                            .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 40)
                    }
                } else if let errorMessage = authViewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)

                        Text("Sync Failed")
                            .font(.system(size: 20, weight: .bold))

                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            dismiss()
                        }) {
                            Text("Close")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.accentColor)
                                )
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Syncing Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        authViewModel.isBackgroundSync = false
                        authViewModel.isLoading = false
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BackgroundSyncView()
        .environmentObject(AuthenticationViewModel())
}
