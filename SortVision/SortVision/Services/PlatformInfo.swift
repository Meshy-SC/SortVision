import Foundation
#if os(iOS) || os(visionOS)
import UIKit
#endif

/// Platform-agnostic device and system information.
///
/// Provides consistent access to platform name, OS version,
/// device model, and app version across iOS, macOS, and visionOS.
/// Used by feedback forms, analytics, and diagnostics.
enum PlatformInfo {

    // MARK: - Platform

    /// Human-readable platform name (e.g., "iOS", "iPad", "macOS", "visionOS").
    static var platformName: String {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "iPad"
        }
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Unknown"
        #endif
    }

    /// Operating system name as reported by the system.
    static var systemName: String {
        #if os(iOS)
        return UIDevice.current.systemName
        #elseif os(macOS)
        return "macOS"
        #elseif os(visionOS)
        return "visionOS"
        #else
        return "Unknown"
        #endif
    }

    /// Operating system version string (e.g., "26.0.1").
    static var systemVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #endif
    }

    /// Device hardware model identifier (e.g., "iPhone17,1", "Mac15,6").
    static var deviceModel: String {
        #if os(iOS)
        return UIDevice.current.model
        #else
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix(while: { $0 != 0 }), as: UTF8.self)
        #endif
    }

    // MARK: - App Info

    /// App marketing version (e.g., "1.2.3").
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// App build number (e.g., "42").
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Formatted version string for display (e.g., "1.2.3 (42)").
    static var versionDisplay: String {
        "\(appVersion) (\(buildNumber))"
    }
}
