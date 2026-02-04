import Foundation
import ServiceManagement

/// Describes failures when configuring launch-at-login behavior.
enum LaunchAtLoginError: Error, CustomStringConvertible {
    case registerFailed(Error)
    case unregisterFailed(Error)
    case requiresApproval
    case unknownStatus(SMAppService.Status)

    /// Provides a human-readable description for logging and UI.
    var description: String {
        switch self {
        case .registerFailed(let error):
            return "Registering the login item failed: \(error.localizedDescription)"
        case .unregisterFailed(let error):
            return "Unregistering the login item failed: \(error.localizedDescription)"
        case .requiresApproval:
            return "Launch at login requires approval in System Settings."
        case .unknownStatus(let status):
            return "Unexpected login item status: \(status)"
        }
    }
}

/// Defines the service-management interface needed for launch-at-login registration.
protocol LaunchAtLoginServicing {
    /// Returns the current login item status.
    var status: SMAppService.Status { get }
    /// Registers the main app as a login item.
    func register() throws
    /// Unregisters the main app as a login item.
    func unregister() throws
}

extension SMAppService: LaunchAtLoginServicing {}

/// Coordinates launch-at-login registration with structured error handling.
@MainActor
final class LaunchAtLoginManager {
    private let service: LaunchAtLoginServicing
    private let logger: (String) -> Void

    /// Creates a manager for controlling the main app login item.
    init(
        service: LaunchAtLoginServicing = SMAppService.mainApp,
        logger: @escaping (String) -> Void = DebugLogger.log
    ) {
        self.service = service
        self.logger = logger
    }

    /// Returns the current login item status.
    func status() -> SMAppService.Status {
        service.status
    }

    /// Synchronizes login item registration with the desired enabled state.
    func sync(enabled: Bool) -> Result<SMAppService.Status, LaunchAtLoginError> {
        let currentStatus = service.status
        if enabled {
            switch currentStatus {
            case .enabled:
                logger("INFO: Launch at login already enabled.")
                return .success(currentStatus)
            case .requiresApproval:
                logger("WARNING: Launch at login needs approval in System Settings.")
                return .failure(.requiresApproval)
            case .notRegistered:
                do {
                    try service.register()
                } catch {
                    logger("ERROR: Launch at login register failed: \(error.localizedDescription)")
                    return .failure(.registerFailed(error))
                }
                let updatedStatus = service.status
                if updatedStatus == .requiresApproval {
                    logger("WARNING: Launch at login needs approval in System Settings.")
                    return .failure(.requiresApproval)
                }
                logger("INFO: Launch at login enabled.")
                return .success(updatedStatus)
            case .notFound:
                logger("ERROR: Launch at login service not found.")
                return .failure(.unknownStatus(currentStatus))
            default:
                return .failure(.unknownStatus(currentStatus))
            }
        } else {
            switch currentStatus {
            case .notRegistered:
                logger("INFO: Launch at login already disabled.")
                return .success(currentStatus)
            case .enabled, .requiresApproval:
                do {
                    try service.unregister()
                } catch {
                    logger("ERROR: Launch at login unregister failed: \(error.localizedDescription)")
                    return .failure(.unregisterFailed(error))
                }
                let updatedStatus = service.status
                logger("INFO: Launch at login disabled.")
                return .success(updatedStatus)
            case .notFound:
                logger("ERROR: Launch at login service not found.")
                return .failure(.unknownStatus(currentStatus))
            default:
                return .failure(.unknownStatus(currentStatus))
            }
        }
    }
}
