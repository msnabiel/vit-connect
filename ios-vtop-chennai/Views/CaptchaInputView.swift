import SwiftUI

struct CaptchaInputView: View {
    let captchaImage: UIImage?
    @Binding var captchaInput: String
    /// When `false`, only the scroll content is shown (parent already provides navigation chrome, e.g. `HomeView` captcha sheet).
    var embedNavigationWrapper: Bool = true
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    (Text("Verify captcha")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                     + Text(" · ")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                     + Text("Enter the characters shown")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)
                .padding(.horizontal, 2)

                captchaImageBlock

                captchaField

                HStack(spacing: 12) {
                    Button(role: .cancel, action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: onSubmit) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(captchaInput.isEmpty)
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    var body: some View {
        Group {
            if embedNavigationWrapper {
                NavigationView {
                    scrollContent
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                scrollContent
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isFocused = false
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
                .frame(height: 80)
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 80)
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
}

#Preview {
    CaptchaInputView(
        captchaImage: UIImage(systemName: "photo"),
        captchaInput: .constant(""),
        embedNavigationWrapper: true,
        onSubmit: {},
        onCancel: {}
    )
}
