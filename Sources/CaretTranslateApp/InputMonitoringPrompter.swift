import Foundation
import IOKit.hidsystem

protocol InputMonitoringChecking {
    func check() -> IOHIDAccessType
    func request() -> Bool
}

struct IOHIDInputMonitoringChecker: InputMonitoringChecking {
    func check() -> IOHIDAccessType {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    }

    func request() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}

final class InputMonitoringPrompter {
    private let checker: InputMonitoringChecking

    init(checker: InputMonitoringChecking = IOHIDInputMonitoringChecker()) {
        self.checker = checker
    }

    func ensureAccess() -> Bool {
        let access = checker.check()
        switch access {
        case kIOHIDAccessTypeGranted:
            return true
        case kIOHIDAccessTypeDenied, kIOHIDAccessTypeUnknown:
            return checker.request()
        default:
            return checker.request()
        }
    }
}
