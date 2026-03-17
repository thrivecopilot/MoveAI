import Foundation

enum MuayThaiDebug {
    static var isEnabled: Bool {
#if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["MOVEAI_MUAY_THAI_DEBUG"] == "1" || env["MOVEAI_POSE_DEBUG"] == "1"
#else
        return false
#endif
    }

    static func log(_ message: @autoclosure () -> String) {
#if DEBUG
        guard isEnabled else { return }
        print("[MuayThaiDebug] \(message())")
#endif
    }

    static func format(_ value: Double, decimals: Int = 3) -> String {
        String(format: "%.*f", decimals, value)
    }
}
