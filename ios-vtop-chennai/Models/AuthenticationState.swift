import Foundation

enum PageType: String {
    case landing = "LANDING"
    case login = "LOGIN"
    case home = "HOME"
    case bodyNotReady = "BODY_NOT_READY"
}

enum CaptchaType {
    case defaultCaptcha
    case googleReCaptcha
}

enum AuthenticationError: Error, LocalizedError {
    case invalidCaptcha
    case invalidCredentials
    case accountLocked
    case maxAttemptsReached
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCaptcha:
            return "Invalid Captcha"
        case .invalidCredentials:
            return "Invalid Username / Password"
        case .accountLocked:
            return "Your Account is Locked"
        case .maxAttemptsReached:
            return "Maximum login attempts reached, open VTOP in your browser to reset your password"
        case .unknown(let message):
            return message
        }
    }
}

struct UserCredentials {
    let username: String
    let password: String
}
