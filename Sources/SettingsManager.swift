//
//  SettingsManager.swift
//  SampleApp
//
//  Created by Mustafa BOLEKEN on 21.10.2025.
//

import SwiftUI

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private enum Keys {
        static let streamManagerHost = "stream_manager_host"
        static let standaloneServerIp = "standalone_server_ip"
        static let appName = "app_name"
        static let nodeGroup = "node_group"
        static let streamName = "stream_name"
        static let userName = "username"
        static let password = "password"
        static let enableDebug = "enable_debug"
        static let dtlsSetup = "dtls_setup"
    }
    
    // Published properties for binding
    @Published var streamManagerHost: String {
        didSet { defaults.set(streamManagerHost, forKey: Keys.streamManagerHost) }
    }
    
    @Published var standaloneServerIp: String {
        didSet { defaults.set(standaloneServerIp, forKey: Keys.standaloneServerIp) }
    }
    
    @Published var appName: String {
        didSet { defaults.set(appName, forKey: Keys.appName) }
    }
    
    @Published var nodeGroup: String {
        didSet { defaults.set(nodeGroup, forKey: Keys.nodeGroup) }
    }
    
    @Published var streamName: String {
        didSet { defaults.set(streamName, forKey: Keys.streamName) }
    }
    
    @Published var userName: String {
        didSet { defaults.set(userName, forKey: Keys.userName) }
    }
    
    @Published var password: String {
        didSet { defaults.set(password, forKey: Keys.password) }
    }
    
    @Published var dtlsSetup: DTLSSetup {
        didSet { defaults.set(dtlsSetup.rawValue, forKey: Keys.dtlsSetup) }
    }
    
    private init() {
        self.streamManagerHost = defaults.string(forKey: Keys.streamManagerHost) ?? ""
        self.standaloneServerIp = defaults.string(forKey: Keys.standaloneServerIp) ?? ""
        self.appName = defaults.string(forKey: Keys.appName) ?? "live"
        self.nodeGroup = defaults.string(forKey: Keys.nodeGroup) ?? "default"
        self.streamName = defaults.string(forKey: Keys.streamName) ?? "myStream"
        self.userName = defaults.string(forKey: Keys.userName) ?? ""
        self.password = defaults.string(forKey: Keys.password) ?? ""
        
        let dtlsValue = defaults.string(forKey: Keys.dtlsSetup) ?? "actpass"
        self.dtlsSetup = DTLSSetup(rawValue: dtlsValue) ?? .actpass
    }
    
    // Static getter methods (like companion object in Android)
    static func getStreamManagerHost() -> String {
        return shared.streamManagerHost
    }
    
    static func getStandaloneServerIp() -> String {
        return shared.standaloneServerIp
    }
    
    static func getAppName() -> String {
        let value = shared.appName.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? "live" : value
    }
    
    static func getNodeGroup() -> String {
        let value = shared.nodeGroup.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? "default" : value
    }
    
    static func getStreamName() -> String {
        let value = shared.streamName.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? "myStream" : value
    }
    
    static func getUserName() -> String {
        return shared.userName
    }
    
    static func getPassword() -> String {
        return shared.password
    }
    
    static func getDtlsSetup() -> String {
        return shared.dtlsSetup.rawValue
    }
    
    static func isDebugEnabled() -> Bool {
        return shared.defaults.bool(forKey: Keys.enableDebug)
    }
    
    func saveSettings() {
        // Trim whitespace and set defaults for empty fields
        streamManagerHost = streamManagerHost.trimmingCharacters(in: .whitespaces)
        standaloneServerIp = standaloneServerIp.trimmingCharacters(in: .whitespaces)
        userName = userName.trimmingCharacters(in: .whitespaces)
        password = password.trimmingCharacters(in: .whitespaces)
        
        if appName.trimmingCharacters(in: .whitespaces).isEmpty {
            appName = "live"
        }
        if nodeGroup.trimmingCharacters(in: .whitespaces).isEmpty {
            nodeGroup = "default"
        }
        if streamName.trimmingCharacters(in: .whitespaces).isEmpty {
            streamName = "myStream"
        }
    }
}

// MARK: - DTLS Setup Enum
enum DTLSSetup: String, CaseIterable {
    case actpass = "actpass"
    case active = "active"
    case passive = "passive"
    
    var displayName: String {
        switch self {
        case .actpass: return "Actpass"
        case .active: return "Active"
        case .passive: return "Passive"
        }
    }
}
