#if !canImport(Darwin)
import Foundation

// Linux Foundation has no String(localized:). This shim exists only so the
// Foundation-only logic and its tests build on Linux; Apple builds use the real API.
extension String {
    init(localized key: String) {
        self = key
    }
}
#endif
