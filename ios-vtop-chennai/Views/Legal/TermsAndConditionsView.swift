import SwiftUI

struct TermsAndConditionsView: View {
    var body: some View {
        ScrollView {
            Text(legalBody)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Terms and conditions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legalBody: String {
        """
        By using this app, you agree to the following terms.

        Unofficial tool
        • This app is not affiliated with, endorsed by, or operated by VIT or VTOP. It provides a client interface to the official VTOP website.

        Acceptable use
        • You must comply with your institution’s rules, honour codes, and VTOP terms of use. Do not use the app to scrape, overload, or misuse institutional systems.

        No warranty
        • The app is provided “as is.” We do not guarantee accuracy of displayed data, availability of VTOP, or uninterrupted service. Always verify important information on the official portal.

        Limitation of liability
        • To the extent permitted by law, we are not liable for any loss arising from use of the app or reliance on information shown in it.

        Changes
        • These terms may be updated. Continued use after changes constitutes acceptance.

        Last updated: April 2026.
        """
    }
}

#Preview {
    NavigationStack {
        TermsAndConditionsView()
    }
}
