import SwiftUI
import WebKit

struct ReCaptchaView: View {
    let webView: WKWebView
    @Binding var isPresented: Bool
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Info
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)

                    Text("Security Verification")
                        .font(.system(size: 20, weight: .semibold))

                    Text("Complete the reCAPTCHA and it will submit automatically")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 24)
                .background(Color(uiColor: .systemBackground))

                Divider()

                // WebView with loading indicator
                ZStack {
                    WebViewContainer(webView: webView)
                        .onAppear {
                            // Hide everything except reCAPTCHA
                            hideLoginFormElements()
                        }

                    if isLoading {
                        ProgressView("Loading reCAPTCHA...")
                            .padding()
                            .background(Color(uiColor: .systemBackground).opacity(0.9))
                            .cornerRadius(10)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .onAppear {
                // Give WebView time to load
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLoading = false
                }
            }
        }
    }

    private func hideLoginFormElements() {
        // Hide everything except the reCAPTCHA iframe
        let hideScript = """
        (function() {
            // Hide the login form fields
            var loginForm = document.getElementById('vtopLoginForm');
            if (loginForm) {
                var inputs = loginForm.querySelectorAll('input[type="text"], input[type="password"]');
                inputs.forEach(function(input) {
                    input.style.display = 'none';
                });

                // Hide labels
                var labels = loginForm.querySelectorAll('label');
                labels.forEach(function(label) {
                    label.style.display = 'none';
                });

                // Hide the submit button
                var submitBtn = loginForm.querySelector('button[type="submit"], input[type="submit"]');
                if (submitBtn) {
                    submitBtn.style.display = 'none';
                }
            }

            // Scroll to reCAPTCHA
            var recaptchaElement = document.querySelector('.g-recaptcha, iframe[src*="recaptcha"]');
            if (recaptchaElement) {
                recaptchaElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        })();
        """

        webView.evaluateJavaScript(hideScript) { _, error in
            if let error = error {
                print("Error hiding form elements: \(error.localizedDescription)")
            }
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
}
