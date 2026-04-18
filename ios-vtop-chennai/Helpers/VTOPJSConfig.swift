import Foundation

/// Injected into WKWebView scripts so release builds skip huge HTML blobs in the native bridge.
enum VTOPJSConfig {
    static var debugLiteral: String {
        #if DEBUG
        "true"
        #else
        "false"
        #endif
    }

    /// Paste after `(function() {` in scripts: assigns `__VTOP_DEBUG__`.
    static let debugVarInit = """
        var __VTOP_DEBUG__ = \(debugLiteral);
    """
}
