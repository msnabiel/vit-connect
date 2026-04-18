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
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Verification required")
                                .font(.system(size: 18, weight: .bold))
                            Text("Enter the captcha to continue syncing.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .center, spacing: 14) {
                                    Image(uiImage: captchaImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 140, height: 76)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .secondarySystemBackground)))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    VStack(alignment: .leading, spacing: 10) {
                                        TextField("Captcha", text: $captchaText)
                                            .textFieldStyle(.roundedBorder)
                                            .autocapitalization(.allCharacters)
                                            .disableAutocorrection(true)
                                            .font(.system(size: 16, weight: .medium))
                                        Button(action: {
                                            authViewModel.submitLogin(captchaText: captchaText)
                                            captchaText = ""
                                        }) {
                                            Text("Submit")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(RoundedRectangle(cornerRadius: 10).fill(captchaText.isEmpty ? Color.gray : Color.accentColor))
                                        }
                                        .disabled(captchaText.isEmpty)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                }
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(uiImage: captchaImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 76)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .secondarySystemBackground)))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    TextField("Captcha", text: $captchaText)
                                        .textFieldStyle(.roundedBorder)
                                        .autocapitalization(.allCharacters)
                                        .disableAutocorrection(true)
                                        .font(.system(size: 16, weight: .medium))
                                    Button(action: {
                                        authViewModel.submitLogin(captchaText: captchaText)
                                        captchaText = ""
                                    }) {
                                        Text("Submit")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(captchaText.isEmpty ? Color.gray : Color.accentColor))
                                    }
                                    .disabled(captchaText.isEmpty)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
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
            .vtopNavLeadingIcon()
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
