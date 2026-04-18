import SwiftUI

struct CaptchaInputView: View {
    let captchaImage: UIImage?
    @Binding var captchaInput: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verify captcha")
                                .font(.system(size: 20, weight: .bold))
                            Text("Enter the characters shown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 14) {
                            captchaImageBlock
                            VStack(alignment: .leading, spacing: 10) {
                                captchaField
                                submitButton
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            captchaImageBlock
                            captchaField
                            submitButton
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    @ViewBuilder
    private var captchaImageBlock: some View {
        if let image = captchaImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 76)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
                )
        } else {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 76)
            .frame(maxWidth: .infinity)
        }
    }

    private var captchaField: some View {
        TextField("Captcha", text: $captchaInput)
            .font(.system(size: 17, weight: .medium))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .textContentType(.oneTimeCode)
            .focused($isFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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

    private var submitButton: some View {
        Button(action: onSubmit) {
            Text("Continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(captchaInput.isEmpty ? Color.accentColor.opacity(0.5) : Color.accentColor)
                )
        }
        .disabled(captchaInput.isEmpty)
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
