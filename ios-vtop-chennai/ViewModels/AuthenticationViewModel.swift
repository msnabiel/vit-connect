import SwiftUI
import WebKit
import Combine
import Foundation

class AuthenticationViewModel: NSObject, ObservableObject {
    // MARK: - Private Properties (declared first for didSet to work)
    private let logger = VTOPLogger.shared
    private var webView: WKWebView?
    private let keychainHelper = KeychainHelper.shared
    private var currentPageType: PageType = .landing
    private let baseURL = "https://vtopcc.vit.ac.in/vtop"
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 10
    var dataManager: DataManager? {
        didSet {
            dataManager?.onSessionExpired = { [weak self] in
                self?.handleSessionExpired()
            }
        }
    }
    private let debugLogPath = "/Users/msnabiel/Desktop/ios-vtop-chennai/.cursor/debug-a1b485.log"
    private var debugInstanceId: String { String(ObjectIdentifier(self).hashValue) }

    /// True while `autoLoginAndSync` is driving a silent re-login (session cookie renewal).
    var isAttemptingSessionRecovery = false

    // #region agent log
    private func emitDebugLog(hypothesisId: String, location: String, message: String, data: [String: Any]) {
        let payload: [String: Any] = [
            "sessionId": "a1b485",
            "runId": "pre-fix",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let raw = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: raw, encoding: .utf8) else { return }

        let output = line + "\n"
        if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
            defer { try? fileHandle.close() }
            do {
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: Data(output.utf8))
            } catch { }
        } else {
            try? output.write(toFile: debugLogPath, atomically: true, encoding: .utf8)
        }
    }
    // #endregion

    // MARK: - Published Properties
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false {
        didSet { syncSignInStallWatchdog() }
    }
    @Published var isAuthenticated: Bool = false {
        didSet {
            // #region agent log
            emitDebugLog(
                hypothesisId: "H6",
                location: "AuthenticationViewModel.isAuthenticated.didSet",
                message: "isAuthenticated didSet fired",
                data: [
                    "instanceId": debugInstanceId,
                    "oldValue": oldValue,
                    "newValue": isAuthenticated
                ]
            )
            // #endregion
            logger.info("📢 isAuthenticated changed from \(oldValue) to \(isAuthenticated)", context: "Auth")
            print("⚠️ DEBUG: isAuthenticated = \(isAuthenticated)")
        }
    }
    @Published var loginSuccess: Bool = false
    @Published var errorMessage: String?
    @Published var showCaptcha: Bool = false {
        didSet { syncSignInStallWatchdog() }
    }
    @Published var captchaImage: UIImage?
    @Published var captchaType: CaptchaType = .defaultCaptcha
    @Published var showReCaptchaWebView: Bool = false {
        didSet { syncSignInStallWatchdog() }
    }
    @Published var rememberMe: Bool = true

    // MARK: - Constants
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
    /// If sign-in never reaches captcha or home within this window, stop spinning and surface guidance.
    private static let signInStallTimeout: TimeInterval = 60
    private var signInStallWatchdogItem: DispatchWorkItem?

    private func syncSignInStallWatchdog() {
        signInStallWatchdogItem?.cancel()
        signInStallWatchdogItem = nil
        guard isLoading, !showCaptcha, !showReCaptchaWebView else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.isLoading, !self.showCaptcha, !self.showReCaptchaWebView else { return }
            self.logger.warning("Sign-in progress stalled — timeout", context: "Auth")
            let msg = DataManager.signInOrSyncStallUserMessage
            self.isLoading = false
            self.isAttemptingSessionRecovery = false
            self.errorMessage = msg
            self.dataManager?.lastDataFetchFailureReason = msg
        }
        signInStallWatchdogItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.signInStallTimeout, execute: work)
    }

    override init() {
        super.init()
        // #region agent log
        emitDebugLog(
            hypothesisId: "H6",
            location: "AuthenticationViewModel.init",
            message: "AuthenticationViewModel instance initialized",
            data: ["instanceId": debugInstanceId]
        )
        // #endregion
        logger.info("🚀 Initializing AuthenticationViewModel", context: "Init")
        checkSavedCredentials()
        checkAuthenticationStatus()
    }

    /// Creates the off-screen `WKWebView` on first use so WebKit/GPU processes are not started while the user is only typing in native login fields.
    private func ensureWebViewReady() {
        guard webView == nil else { return }
        setupWebView()
    }

    // MARK: - Check Authentication Status
    private func checkAuthenticationStatus() {
        let isSignedIn = UserDefaults.standard.bool(forKey: "isSignedIn")
        // #region agent log
        emitDebugLog(
            hypothesisId: "H4",
            location: "AuthenticationViewModel.checkAuthenticationStatus",
            message: "Startup auth status check",
            data: [
                "isSignedIn": isSignedIn,
                "hasSavedUsername": keychainHelper.getUsername() != nil,
                "hasSavedPassword": keychainHelper.getPassword() != nil
            ]
        )
        // #endregion
        logger.debug("Checking authentication status: isSignedIn=\(isSignedIn)", context: "Auth")
        print("⚠️ DEBUG: checkAuthenticationStatus - isSignedIn=\(isSignedIn)")

        if isSignedIn && keychainHelper.getUsername() != nil && keychainHelper.getPassword() != nil {
            logger.success("User already authenticated, restoring session", context: "Auth")
            print("⚠️ DEBUG: Setting isAuthenticated=true on startup")
            isAuthenticated = true
        } else {
            logger.info("No saved session found", context: "Auth")
            print("⚠️ DEBUG: No saved session, isAuthenticated remains false")
        }
    }

    // MARK: - WebView Setup
    private func setupWebView() {
        logger.debug("Setting up WebView with custom user agent", context: "WebView")

        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // Add message handler for JavaScript bridge
        userContentController.add(self, name: "iOSApp")

        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
        webView?.customUserAgent = userAgent

        // Enable JavaScript
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webView?.configuration.defaultWebpagePreferences = preferences

        logger.success("WebView setup complete", context: "WebView")
    }

    // MARK: - Check Saved Credentials
    private func checkSavedCredentials() {
        logger.debug("Checking for saved credentials in Keychain", context: "Keychain")

        if let savedUsername = keychainHelper.getUsername(),
           let savedPassword = keychainHelper.getPassword() {
            self.username = savedUsername
            self.password = savedPassword
            AppCacheSettings.setActiveRegisterNumber(savedUsername)
            logger.info("Found saved credentials for user: \(savedUsername)", context: "Keychain")
        } else {
            logger.debug("No saved credentials found", context: "Keychain")
        }
    }

    // MARK: - Sign In
    func signIn() {
        logger.info("🔐 Sign in initiated for user: \(username)", context: "SignIn")
        AppCacheSettings.setActiveRegisterNumber(username)

        guard !username.isEmpty, !password.isEmpty else {
            let error = "Please enter username and password"
            logger.warning(error, context: "SignIn")
            errorMessage = error
            return
        }

        isLoading = true
        errorMessage = nil
        connectionAttempts = 0

        // Save credentials to Keychain only if remember me is enabled
        if rememberMe {
            logger.debug("Saving credentials to Keychain (Remember Me enabled)", context: "SignIn")
            let saved = keychainHelper.save(username: username, password: password)
            if saved {
                logger.success("Credentials saved successfully", context: "Keychain")
            } else {
                logger.error("Failed to save credentials", context: "Keychain", code: .failedToFetchCredentials)
            }
        } else {
            logger.debug("Skipping credential save (Remember Me disabled)", context: "SignIn")
        }

        // Start authentication flow
        loadLoginPage()
    }

    // MARK: - Load Login Page
    private func loadLoginPage() {
        ensureWebViewReady()
        logger.info("📄 Loading login page: \(baseURL)/login", context: "WebView")

        guard let url = URL(string: "\(baseURL)/login") else {
            let error = "Invalid URL"
            logger.error(error, context: "WebView")
            errorMessage = error
            isLoading = false
            return
        }

        let request = URLRequest(url: url)
        webView?.load(request)
        logger.debug("URLRequest created and loading...", context: "WebView")
    }

    // MARK: - Detect Page Type
    private func detectPageType() {
        logger.debug("🔍 Detecting page type...", context: "PageDetection")

        let script = """
        (function() {
            const response = {
                page_type: 'LANDING'
            };

            if (document.body === null) {
                response.page_type = 'BODY_NOT_READY';
            } else if (document.querySelector('input[id="authorizedIDX"]') !== null) {
                response.page_type = 'HOME';
            } else if (document.querySelector('form[id="vtopLoginForm"]') !== null) {
                response.page_type = 'LOGIN';
            }

            return JSON.stringify(response);
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("JavaScript evaluation failed: \(error.localizedDescription)", context: "PageDetection", code: .loginAttemptParsingError)
                return
            }

            guard let jsonString = result as? String else {
                self.logger.error("Invalid JavaScript result type", context: "PageDetection")
                return
            }

            self.logger.debug("JavaScript result: \(jsonString)", context: "PageDetection")

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let pageTypeString = json["page_type"],
                  let pageType = PageType(rawValue: pageTypeString) else {
                self.logger.error("Failed to parse page type from response", context: "PageDetection")
                return
            }

            self.logger.info("✅ Detected page type: \(pageTypeString)", context: "PageDetection")

            DispatchQueue.main.async {
                self.currentPageType = pageType
                self.handlePageType(pageType)
            }
        }
    }

    // MARK: - Handle Page Type
    private func handlePageType(_ pageType: PageType) {
        logger.info("📋 Handling page type: \(pageType.rawValue)", context: "PageHandler")

        switch pageType {
        case .landing:
            logger.debug("Landing page detected, initiating sign-in flow", context: "PageHandler")
            connectionAttempts += 1
            if connectionAttempts >= maxConnectionAttempts {
                logger.error("Maximum connection attempts reached (\(maxConnectionAttempts))", context: "PageHandler", code: .serverConnectionTimeout)
                DispatchQueue.main.async {
                    self.errorMessage = "Couldn't connect to the server. Please try again."
                    self.isLoading = false
                }
                return
            }
            openSignIn()
        case .login:
            logger.debug("Login page ready, detecting captcha type", context: "PageHandler")
            detectCaptchaType()
        case .home:
            logger.success("🎉 Home page detected - authentication successful!", context: "PageHandler")
            // Fresh sign-in: app was not marked authenticated yet.
            if !isAuthenticated {
                handleSuccessfulAuthentication()
            } else if isAttemptingSessionRecovery {
                // Cookie/session expired but the app still had isSignedIn — renew WebView session and re-extract CSRF.
                logger.info("Home after silent re-login — refreshing server session in DataManager", context: "PageHandler")
                finalizeSilentWebSessionRenewal()
            } else {
                logger.debug("Already authenticated, skipping handleSuccessfulAuthentication", context: "PageHandler")
            }
        case .bodyNotReady:
            logger.warning("Page body not ready, retrying in 0.5s...", context: "PageHandler")
            // Wait and retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.detectPageType()
            }
        }
    }

    // MARK: - Open Sign In
    private func openSignIn() {
        logger.info("🚪 Opening sign-in page (attempt \(connectionAttempts)/\(maxConnectionAttempts))...", context: "SignIn")

        let script = """
        (function() {
            $.ajax({
                type: 'POST',
                url: '/vtop/prelogin/setup',
                data: $('#stdForm').serialize(),
                async: false,
                success: function(res) {
                    window.location.href = '/vtop/login';
                }
            });
            return true;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                self?.logger.error("Failed to open sign-in: \(error.localizedDescription)", context: "SignIn")
            } else {
                self?.logger.success("Sign-in page navigation initiated", context: "SignIn")
            }
            // Page will reload automatically, and we'll detect it in navigationDelegate
        }
    }

    // MARK: - Detect Captcha Type
    private func detectCaptchaType() {
        logger.info("🔍 Detecting captcha type...", context: "Captcha")

        let script = """
        (function() {
            const response = {
                captcha_type: 'DEFAULT'
            };
            if (document.querySelector('input[id="gResponse"]') !== null) {
                response.captcha_type = 'GRECAPTCHA';
            }
            return JSON.stringify(response);
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Captcha type detection failed: \(error.localizedDescription)", context: "Captcha", code: .captchaTypeParsingError)
                return
            }

            guard let jsonString = result as? String else {
                self.logger.error("Invalid captcha detection result", context: "Captcha", code: .captchaTypeParsingError)
                return
            }

            self.logger.debug("Captcha detection result: \(jsonString)", context: "Captcha")

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let captchaTypeString = json["captcha_type"] else {
                self.logger.error("Failed to parse captcha type", context: "Captcha", code: .captchaTypeParsingError)
                return
            }

            self.logger.info("✅ Captcha type detected: \(captchaTypeString)", context: "Captcha")

            DispatchQueue.main.async {
                if captchaTypeString == "GRECAPTCHA" {
                    self.logger.info("⚠️ Google reCAPTCHA detected - attempting automatic execution", context: "Captcha")
                    self.captchaType = .googleReCaptcha
                    // Don't show WebView - execute reCAPTCHA automatically
                    self.executeCaptcha()
                } else {
                    self.logger.info("✅ Using default image captcha - No webpage needed", context: "Captcha")
                    self.captchaType = .defaultCaptcha
                    self.getCaptcha()
                }
            }
        }
    }

    // MARK: - Get Default Captcha
    private func getCaptcha() {
        logger.info("📷 Fetching default captcha image...", context: "Captcha")

        let script = """
        (function() {
            var img = document.querySelector('#captchaBlock img');
            var hasReCaptcha = document.querySelector('.g-recaptcha, iframe[src*="recaptcha"]') !== null;
            return {
                captcha: img ? img.src : null,
                hasReCaptcha: hasReCaptcha
            };
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch captcha: \(error.localizedDescription)", context: "Captcha", code: .captchaImageParsingError)
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load captcha. Please try again."
                    self.isLoading = false
                }
                return
            }

            guard let dict = result as? [String: Any] else {
                self.logger.error("Invalid captcha response", context: "Captcha", code: .captchaImageParsingError)
                return
            }

            // Double-check for reCAPTCHA
            let hasReCaptcha = dict["hasReCaptcha"] as? Bool ?? false
            if hasReCaptcha {
                self.logger.warning("⚠️ reCAPTCHA detected during default captcha fetch!", context: "Captcha")
                self.logger.info("Switching to reCAPTCHA mode...", context: "Captcha")
                DispatchQueue.main.async {
                    self.captchaType = .googleReCaptcha
                    self.showReCaptchaWebView = true
                    self.executeCaptcha()
                }
                return
            }

            guard let captchaDataURL = dict["captcha"] as? String else {
                self.logger.error("No captcha image found", context: "Captcha", code: .captchaImageParsingError)
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load captcha image."
                    self.isLoading = false
                }
                return
            }

            self.logger.debug("Captcha data URL received, length: \(captchaDataURL.count)", context: "Captcha")

            // Extract base64 data
            if let base64String = captchaDataURL.components(separatedBy: ",").last,
               let imageData = Data(base64Encoded: base64String),
               let image = UIImage(data: imageData) {
                self.logger.success("✅ Captcha image loaded successfully (no reCAPTCHA)", context: "Captcha")
                DispatchQueue.main.async {
                    self.captchaImage = image
                    self.showCaptcha = true
                    self.isLoading = false
                }
            } else {
                self.logger.error("Failed to decode captcha base64 image", context: "Captcha", code: .captchaImageParsingError)
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to decode captcha image."
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Execute Google reCaptcha
    private func executeCaptcha() {
        logger.info("🔐 Executing Google reCaptcha...", context: "Captcha")

        let script = """
        function callBuiltValidation(token) {
            window.webkit.messageHandlers.iOSApp.postMessage({
                action: 'captchaToken',
                token: token
            });
        }
        (function() {
            var executeInterval = setInterval(function() {
                try {
                    grecaptcha.execute();
                    clearInterval(executeInterval);
                } catch (err) { }
            }, 500);
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                self?.logger.error("reCaptcha execution failed: \(error.localizedDescription)", context: "Captcha", code: .captchaExecutionError)
            } else {
                self?.logger.success("reCaptcha script injected successfully", context: "Captcha")
            }
        }
    }

    // MARK: - Submit Login
    func submitLogin(captchaText: String) {
        logger.info("🔑 Submitting login with captcha: \(captchaText.prefix(3))***", context: "Login")

        let escapedUsername = username.replacingOccurrences(of: "'", with: "\\'")
        let escapedPassword = password.replacingOccurrences(of: "'", with: "\\'")
        let escapedCaptcha = captchaText.replacingOccurrences(of: "'", with: "\\'")

        let script = """
        (function() {
            $('#vtopLoginForm [name="username"]').val('\(escapedUsername)');
            $('#vtopLoginForm [name="password"]').val('\(escapedPassword)');
            $('#vtopLoginForm [name="captchaStr"]').val('\(escapedCaptcha)');
            $('#vtopLoginForm [name="gResponse"]').val('\(escapedCaptcha)');

            var response = {
                authorised: false,
                error_message: null,
                error_code: 0,
                raw_response: ''
            };

            $.ajax({
                type: 'POST',
                url: '/vtop/login',
                data: $('#vtopLoginForm').serialize(),
                async: false,
                success: function(res) {
                    response.raw_response = res;

                    if(res.search('___INTERNAL___RESPONSE___') == -1) {
                        $('#page_outline').html(res);

                        if (res.includes('authorizedIDX')) {
                            response.authorised = true;
                            return;
                        }

                        var pageContent = res.toLowerCase();

                        var invalidCaptchaRegex = new RegExp(/invalid\\s*captcha/);
                        var invalidCredentialsRegex = new RegExp(/invalid\\s*(user\\s*name|login\\s*id|user\\s*id)\\s*\\/\\s*password/);
                        var accountLockedRegex = new RegExp(/account\\s*is\\s*locked/);
                        var maxFailAttemptsRegex = new RegExp(/maximum\\s*fail\\s*attempts\\s*reached/);

                        if (invalidCaptchaRegex.test(pageContent)) {
                            response.error_message = 'Invalid Captcha';
                            response.error_code = 1;
                        } else if(invalidCredentialsRegex.test(pageContent)) {
                            response.error_message = 'Invalid Username / Password';
                            response.error_code = 2;
                        } else if(accountLockedRegex.test(pageContent)) {
                            response.error_message = 'Your Account is Locked';
                            response.error_code = 3;
                        } else if(maxFailAttemptsRegex.test(pageContent)) {
                            response.error_message = 'Maximum login attempts reached, open VTOP in your browser to reset your password';
                            response.error_code = 4;
                        } else {
                            response.error_message = 'Unknown error';
                            response.error_code = 5;
                        }
                    }
                }
            });

            return response;
        })();
        """

        isLoading = true
        showCaptcha = false

        logger.debug("Executing login JavaScript...", context: "Login")

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Login JavaScript failed: \(error.localizedDescription)", context: "Login", code: .loginAttemptParsingError)
                DispatchQueue.main.async {
                    self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }

            // JavaScript returns an object directly, not a JSON string
            guard let responseDict = result as? [String: Any] else {
                self.logger.error("Invalid login response type: \(type(of: result))", context: "Login")
                DispatchQueue.main.async {
                    self.errorMessage = "Authentication failed: Invalid response type"
                    self.isLoading = false
                }
                return
            }

            let isAuthorised = responseDict["authorised"] as? Bool ?? false
            let errorCode = responseDict["error_code"] as? Int ?? 0
            let errorMessage = responseDict["error_message"] as? String ?? "Unknown error"
            let rawResponse = responseDict["raw_response"] as? String ?? ""

            self.logger.debug("Login response - Authorised: \(isAuthorised), Error Code: \(errorCode)", context: "Login")

            if !rawResponse.isEmpty {
                print("🔍 FULL /vtop/login response (length=\(rawResponse.count)):")
                print(rawResponse)
            }

            DispatchQueue.main.async {
                if isAuthorised {
                    self.logger.success("🎉 Login successful!", context: "Login")

                    // Navigate to home page first (like Android does with reloadPage("/content"))
                    self.logger.info("📍 Navigating to home page (/vtop/content) after successful login", context: "Login")
                    if let url = URL(string: "\(self.baseURL)/content") {
                        let request = URLRequest(url: url)
                        self.webView?.load(request)
                    }

                    // The page will load, detectPageType will run, and handleSuccessfulAuthentication will be called
                } else {
                    self.logger.warning("Login failed with error code \(errorCode): \(errorMessage)", context: "Login")

                    // Handle different error codes like Android
                    if errorCode == 1 {
                        // Invalid captcha - retry with new captcha
                        self.logger.info("Invalid captcha, will retry with new captcha", context: "Login")
                        self.handleLoginError(errorMessage)
                        // Reload login page to get new captcha
                        self.loadLoginPage()
                    } else if errorCode == 2 {
                        // Invalid credentials - force sign out
                        self.logger.error("Invalid credentials, forcing sign out", context: "Login")
                        self.handleLoginError(errorMessage)
                        self.signOut()
                    } else if errorCode == 3 || errorCode == 4 {
                        // Account locked or max attempts
                        self.logger.error("Account locked or max attempts", context: "Login")
                        self.handleLoginError(errorMessage)
                    } else {
                        // Unknown error - show raw response in logs
                        self.logger.error("Unknown error (code 5). Check raw HTML response above.", context: "Login")
                        self.handleLoginError(errorMessage)
                    }
                }
            }
        }
    }

    // MARK: - Handle Login Error
    private func handleLoginError(_ message: String) {
        isLoading = false

        switch message {
        case "Invalid Captcha":
            errorMessage = message
            // Retry captcha
            detectCaptchaType()
        case "Invalid Username / Password":
            errorMessage = message
            // Force user to re-enter credentials
        case "Your Account is Locked", "Maximum login attempts reached":
            errorMessage = message
        default:
            errorMessage = "Authentication failed: \(message)"
        }
    }

    /// After captcha + POST login while the app still considered the user signed in (session cookie expired).
    private func finalizeSilentWebSessionRenewal() {
        DispatchQueue.main.async {
            self.showCaptcha = false
            self.captchaImage = nil
            self.showReCaptchaWebView = false
            self.errorMessage = nil
            self.isLoading = false
            self.isAttemptingSessionRecovery = false
            self.connectionAttempts = 0

            if let webView = self.webView {
                self.dataManager?.setWebView(webView)
                self.dataManager?.extractSessionData()
            } else {
                self.logger.warning("WebView is nil after silent renewal", context: "Auth")
            }
        }
    }

    // MARK: - Handle Successful Authentication
    private func handleSuccessfulAuthentication() {
        logger.info("🚀 handleSuccessfulAuthentication called", context: "Auth")
        // #region agent log
        emitDebugLog(
            hypothesisId: "H1",
            location: "AuthenticationViewModel.handleSuccessfulAuthentication",
            message: "Entered successful auth handler",
            data: [
                "isLoadingBefore": isLoading,
                "isAuthenticatedBefore": isAuthenticated,
                "loginSuccessBefore": loginSuccess
            ]
        )
        // #endregion

        DispatchQueue.main.async {
            self.logger.info("Setting loginSuccess = true", context: "Auth")

            // Show success state first
            self.loginSuccess = true
            self.errorMessage = nil
            self.isLoading = false
            self.isAuthenticated = true
            self.loginSuccess = false
            UserDefaults.standard.set(true, forKey: "isSignedIn")

            // #region agent log
            self.emitDebugLog(
                hypothesisId: "H1",
                location: "AuthenticationViewModel.handleSuccessfulAuthentication",
                message: "Auth state updated to authenticated",
                data: [
                    "isLoadingAfter": self.isLoading,
                    "isAuthenticatedAfter": self.isAuthenticated,
                    "loginSuccessAfter": self.loginSuccess,
                    "userDefaultsSignedIn": UserDefaults.standard.bool(forKey: "isSignedIn")
                ]
            )
            // #endregion

            self.logger.success("✅ Authentication state updated, should transition to HomeView", context: "Auth")

            // Start data fetching - WebView should be on home page with authorizedIDX element
            if let webView = self.webView {
                self.dataManager?.setWebView(webView)
                self.dataManager?.extractSessionData()

                self.isAttemptingSessionRecovery = false
            } else {
                self.logger.warning("WebView is nil, cannot start data fetching", context: "Auth")
            }
        }
    }

    // MARK: - Sign Out
    func signOut() {
        // #region agent log
        emitDebugLog(
            hypothesisId: "H3",
            location: "AuthenticationViewModel.signOut",
            message: "signOut invoked",
            data: [
                "isAuthenticatedBefore": isAuthenticated,
                "usernameEmptyBefore": username.isEmpty,
                "userDefaultsSignedInBefore": UserDefaults.standard.bool(forKey: "isSignedIn")
            ]
        )
        // #endregion
        keychainHelper.deleteAll()
        UserDefaults.standard.set(false, forKey: "isSignedIn")
        isAuthenticated = false
        username = ""
        password = ""
        isLoading = false
        showCaptcha = false
        captchaImage = nil
        showReCaptchaWebView = false
        isAttemptingSessionRecovery = false
        errorMessage = nil
        if AppCacheSettings.clearCacheOnSignOutEnabled() {
            dataManager?.clearCachedVTOPData()
        }
        dataManager?.lastDataFetchFailureReason = nil

        // Clear webview cookies
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) { }
        }
    }

    // MARK: - Get WebView (for reCaptcha display)
    func getWebView() -> WKWebView? {
        ensureWebViewReady()
        return webView
    }

    // MARK: - Auto Login and Sync
    func autoLoginAndSync() {
        logger.info("🔄 Auto login and sync initiated", context: "AutoSync")

        // Check if we have saved credentials
        guard let savedUsername = keychainHelper.getUsername(),
              let savedPassword = keychainHelper.getPassword() else {
            logger.warning("No saved credentials found for auto-login, forcing sign out", context: "AutoSync")
            signOut()
            return
        }

        // Set credentials
        self.username = savedUsername
        self.password = savedPassword
        AppCacheSettings.setActiveRegisterNumber(savedUsername)

        self.isAttemptingSessionRecovery = true

        ensureWebViewReady()

        logger.info("Starting login for auto-sync...", context: "AutoSync")
        isLoading = true
        errorMessage = nil
        connectionAttempts = 0

        // Start authentication flow
        loadLoginPage()
    }

    // MARK: - Trigger Sync (when already authenticated)
    func triggerSync() {
        logger.info("🔄 Manual sync triggered", context: "Sync")
        ensureWebViewReady()

        if let webView = self.webView {
            dataManager?.setWebView(webView)
            dataManager?.requestUserFullSyncFromToolbar()
        } else {
            logger.warning("No WebView available, initiating auto-login", context: "Sync")
            autoLoginAndSync()
        }
    }
}

// MARK: - Session recovery
extension AuthenticationViewModel {
    private func handleSessionExpired() {
        // If we're already in the middle of a login/captcha flow, don't start another attempt.
        guard !isAttemptingSessionRecovery,
              !isLoading,
              !showCaptcha,
              !showReCaptchaWebView else { return }

        logger.warning("Session expired during sync; attempting auto re-login", context: "AutoSync")
        autoLoginAndSync()
    }
}

// MARK: - WKNavigationDelegate
extension AuthenticationViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.success("✓ WebView finished loading page: \(webView.url?.absoluteString ?? "unknown")", context: "WebView")
        // Detect page type after page loads
        detectPageType()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("WebView navigation failed: \(error.localizedDescription)", context: "WebView", code: .serverConnectionTimeout)
        DispatchQueue.main.async {
            self.errorMessage = "Network error: \(error.localizedDescription)"
            self.isLoading = false
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        logger.debug("WebView started loading: \(webView.url?.absoluteString ?? "unknown")", context: "WebView")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("WebView provisional navigation failed: \(error.localizedDescription)", context: "WebView", code: .serverConnectionTimeout)
        DispatchQueue.main.async {
            self.errorMessage = "Failed to load page: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
}

// MARK: - WKScriptMessageHandler
extension AuthenticationViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let action = dict["action"] as? String else {
            return
        }

        switch action {
        case "captchaToken":
            if let token = dict["token"] as? String {
                submitLogin(captchaText: token)
            }
        default:
            break
        }
    }
}
