import Foundation

enum SecureFieldDetector {
    static func isSecure(role: String?, subrole: String?) -> Bool {
        let secureValue = "AXSecureTextField"
        return role == secureValue || subrole == secureValue
    }
}
