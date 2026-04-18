# Setup Instructions

## Required: Add Face ID Permission

To enable biometric authentication (Face ID/Touch ID), you must add the following to your `Info.plist`:

### Option 1: Using Xcode UI
1. Open `ios-vtop-chennai.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "ios-vtop-chennai" target
4. Go to the "Info" tab
5. Click the "+" button to add a new key
6. Add:
   - **Key**: Privacy - Face ID Usage Description
   - **Type**: String
   - **Value**: "Authenticate to sign in to VTOP"

### Option 2: Edit Info.plist Directly
Add this inside the `<dict>` tag:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to sign in to VTOP</string>
```

---

## Build Instructions

1. Open `ios-vtop-chennai.xcodeproj` in Xcode
2. Select your target device or simulator (iOS 15.0+)
3. Add the Face ID permission (see above)
4. Build and run (Cmd+R)

---

## File Structure

```
ios-vtop-chennai/
├── Helpers/
│   └── KeychainHelper.swift              # Secure credential storage
├── Models/
│   ├── AuthenticationState.swift        # Auth models and enums
│   └── ErrorCode.swift                   # Error codes & Logger
├── ViewModels/
│   └── AuthenticationViewModel.swift    # Auth logic with logging
├── Views/
│   ├── LoginView.swift                   # Modern login UI
│   ├── CaptchaInputView.swift            # Captcha input
│   ├── ReCaptchaView.swift               # Google reCaptcha
│   ├── HomeView.swift                    # Post-auth home
│   └── DebugConsoleView.swift            # In-app debug console
└── ios_vtop_chennaiApp.swift             # Main app entry
```

---

## Testing

### Test Login Flow:
1. Run the app
2. Enter VTOP credentials
3. Open Debug Console (terminal icon)
4. Click "Sign In"
5. Watch logs in real-time

### Test Biometric Auth:
1. Sign in once with "Remember me" enabled
2. Quit and reopen app
3. Tap "Use Face ID" button
4. Authenticate with Face ID
5. Should auto-login

### Test Debug Console:
1. Open debug console
2. Filter by different log levels
3. Try exporting logs
4. Clear logs and refresh

---

## Troubleshooting

### "Unknown error" during authentication:
1. Open Debug Console
2. Look for red error messages with [Code: XXX]
3. Check LOGIN_IMPROVEMENTS.md for error code meanings
4. Export logs for detailed analysis

### Face ID not appearing:
1. Check Info.plist has NSFaceIDUsageDescription
2. Test on real device (not simulator)
3. Ensure "Remember me" was enabled during first login
4. Check Keychain has saved credentials

### WebView not loading:
1. Check internet connection
2. Look at debug console for network errors
3. Check if VTOP server is accessible
4. Look for error code 101 (timeout)

---

## Known Issues

1. **User Agent Blocking**: VTOP may block certain user agents. Currently using a hardcoded iOS user agent. If blocked (error 107), will need to implement automatic user agent rotation.

2. **Captcha Changes**: If VTOP changes their captcha system, may get error 103-105. Will need to update captcha parsing logic.

3. **Website Structure Changes**: If VTOP updates their website HTML, page detection may fail (error 106). Will need to update selectors.

---

## Next Steps

### Phase 2: In-App Authentication Improvements
- [ ] Implement automatic user agent fetching/rotation
- [ ] Add semester selection dialog after login
- [ ] Add detailed progress states ("Connecting...", "Verifying captcha...", etc.)
- [ ] Implement WebView cleanup and cookie management
- [ ] Add captcha refresh button

### Phase 3: Post-Authentication Features
- [ ] Sync courses, marks, attendance, timetable
- [ ] Implement proper data models
- [ ] Add Core Data persistence
- [ ] Create actual home screen with real data
- [ ] Add assignments and performance tabs

### Phase 4: Advanced Features
- [ ] Firebase Crashlytics integration
- [ ] Push notifications
- [ ] Widget support
- [ ] Moodle integration
- [ ] Offline mode

---

## Important Notes

- All authentication happens **in-app** using WKWebView (no external browser)
- Credentials are stored **securely** in iOS Keychain with AES256 encryption
- Logging is **comprehensive** with 100+ error codes matching Android
- Debug console provides **real-time** visibility into authentication flow
- Biometric authentication is **completely secure** using LocalAuthentication framework

---

## Support

If you encounter issues:
1. Check Debug Console for detailed logs
2. Export logs and review error codes
3. Check LOGIN_IMPROVEMENTS.md for feature documentation
4. Verify internet connection and VTOP server availability

---

**Happy coding! 🎉**
