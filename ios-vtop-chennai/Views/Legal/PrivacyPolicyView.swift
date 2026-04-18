import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text(legalBody)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
        .vtopNavLeadingIcon()
    }

    private var legalBody: String {
        """
        This app is an unofficial companion for VTOP. This privacy policy describes how the app handles information on your device.

        Data we access
        • Session identifiers and page content loaded in the in-app browser are used only to show your academic data (attendance, marks, profile, etc.) as you request.
        • Credentials you enter are used to sign in to VTOP through the official site; they are not sent to us or to third parties by this app.

        Storage
        • Cached responses and preferences may be stored on your device to improve loading. You can sign out or delete the app to remove local data.

        Third parties
        • VTOP is operated by your institution. Their privacy practices apply when you use their website. This app does not replace or override VTOP’s policies.

        Contact
        • For questions about this app build, use the “Bugs & suggestions” link in Profile. For institutional data practices, contact your university.

        Last updated: April 2026.
        """
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
