# iOS VTOP Chennai

iOS SwiftUI implementation of the VTOP Chennai Student App.

## Project Structure

```
ios-vtop-chennai/
├── Helpers/
│   └── KeychainHelper.swift          # Secure credential storage
├── Models/
│   └── AuthenticationState.swift    # Auth models and enums
├── ViewModels/
│   └── AuthenticationViewModel.swift # Auth logic and WebView handling
├── Views/
│   ├── LoginView.swift               # Login screen
│   ├── CaptchaInputView.swift        # Default captcha input
│   ├── ReCaptchaView.swift           # Google reCaptcha WebView
│   └── HomeView.swift                # Post-auth home with tabs
└── ios_vtop_chennaiApp.swift         # Main app entry
```

## Features

### Authentication
- Secure credential storage using iOS Keychain
- WKWebView-based authentication with JavaScript bridge
- Support for both default captcha and Google reCaptcha
- Automatic page detection and navigation

### Post-Authentication Screens
- **Home Tab**: Greeting, CGPA display, timetable
- **Assignments Tab**: Assignment list with status
- **Performance Tab**: Course-wise marks
- **Profile Tab**: Settings and sign out

## Reference

The `android-vtop-chennai-reference/` folder contains the original Android app implementation used as a reference for this iOS port.

## Build Instructions

1. Open `ios-vtop-chennai.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (Cmd+R)

## Notes

- Minimum iOS version: 15.0
- Requires internet connection for authentication
- Uses VIT's VTOP portal: https://vtopcc.vit.ac.in
