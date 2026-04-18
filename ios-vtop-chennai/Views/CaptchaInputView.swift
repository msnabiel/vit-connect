import SwiftUI

struct CaptchaInputView: View {
    let captchaImage: UIImage?
    @Binding var captchaInput: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .padding(.top, 20)

                    Text("Verify Captcha")
                        .font(.system(size: 24, weight: .bold))

                    Text("Enter the characters you see below")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Captcha Image
                if let image = captchaImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading captcha...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                }

                // Captcha Input Field
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Enter captcha", text: $captchaInput)
                        .font(.system(size: 17, weight: .medium))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.oneTimeCode)
                        .focused($isFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isFocused ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .submitLabel(.done)
                        .onSubmit {
                            if !captchaInput.isEmpty {
                                onSubmit()
                            }
                        }
                }
                .padding(.horizontal, 24)

                // Submit Button
                Button(action: onSubmit) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(captchaInput.isEmpty ? Color.accentColor.opacity(0.5) : Color.accentColor)
                        )
                }
                .disabled(captchaInput.isEmpty)
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}

#Preview {
    CaptchaInputView(
        captchaImage: UIImage(systemName: "photo"),
        captchaInput: .constant(""),
        onSubmit: {},
        onCancel: {}
    )
}
