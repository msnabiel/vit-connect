# Contributing to VIT Connect

Thanks for your interest in improving VIT Connect. Bug reports, focused fixes, documentation updates, and feature proposals are welcome.

## Before you start

- For a bug, include the device or simulator, iOS version, steps to reproduce, and what you expected to happen.
- For a larger feature, open an issue first to discuss the behavior and scope.
- Never include VTOP credentials, real student records, or other private information in issues, screenshots, logs, or test fixtures. Redact identifying details from diagnostic material.

## Set up the project

1. Install Xcode with the iOS 18.2 SDK or newer.
2. Open `ios-vtop-chennai.xcodeproj`.
3. Select the **VIT Connect** scheme and an available iOS 18.2 or newer simulator.
4. Build and run. Live academic data requires your own VTOP account; do not add credentials to the repository.

## Make and verify your change

- Keep changes focused and follow the existing Swift and SwiftUI patterns in the affected area.
- Use native SwiftUI controls and provide accessibility labels for controls that only show an image.
- Add or update tests when behavior changes, and run the relevant tests with the **VIT Connect** scheme in Xcode.
- Build the app before submitting when possible. GitHub Actions also runs an Xcode build and analysis without code signing.
- Do not commit generated build output, Xcode user state, credentials, or private student data.

## Open a pull request

Use a short, descriptive title. In the description, explain:

- What changed and why
- How you verified the change
- Any screenshots or recordings needed to review a UI change (with private data redacted)
- Any follow-up work or known limitations

Keep the pull request focused. If it addresses an issue, link that issue in the description.

## License

By submitting a contribution, you agree that it may be distributed under the repository's [Apache License 2.0](LICENSE), unless a separate agreement applies.
