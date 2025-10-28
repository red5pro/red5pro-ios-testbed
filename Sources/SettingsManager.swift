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
        static let standaloneServerPort = "standalone_server_port"
        static let turnUrl = "turn_url"
        static let turnUsername = "turn_username"
        static let turnPassword = "turn_password"
        static let sdkLicenseKey = "sdk_license_key"
        static let appName = "app_name"
        static let nodeGroup = "node_group"
        static let streamName = "stream_name"
        static let userName = "username"
        static let password = "password"
        static let pubnubPubKey = "pubnub_publish_key"
        static let pubnubSubKey = "pubnub_subscribe_key"
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
    
    @Published var standaloneServerPort: Int {
        didSet { defaults.set(standaloneServerPort, forKey: Keys.standaloneServerPort) }
    }
    
    @Published var turnUrl: String {
        didSet { defaults.set(turnUrl, forKey: Keys.turnUrl) }
    }
    
    @Published var turnUsername: String {
        didSet { defaults.set(turnUsername, forKey: Keys.turnUsername) }
    }
    
    @Published var turnPassword: String {
        didSet { defaults.set(turnPassword, forKey: Keys.turnPassword) }
    }
    
    @Published var sdkLicenseKey: String {
        didSet { defaults.set(sdkLicenseKey, forKey: Keys.sdkLicenseKey) }
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
    
    @Published var pubnubPubKey: String {
        didSet { defaults.set(pubnubPubKey, forKey: Keys.pubnubPubKey) }
    }
    
    @Published var pubnubSubKey: String {
        didSet { defaults.set(pubnubSubKey, forKey: Keys.pubnubSubKey) }
    }
    
    @Published var dtlsSetup: DTLSSetup {
        didSet { defaults.set(dtlsSetup.rawValue, forKey: Keys.dtlsSetup) }
    }
    
    private init() {
        self.streamManagerHost = defaults.string(forKey: Keys.streamManagerHost) ?? ""
        self.standaloneServerIp = defaults.string(forKey: Keys.standaloneServerIp) ?? ""
        self.standaloneServerPort = defaults.integer(forKey: Keys.standaloneServerPort)
        self.turnUrl = defaults.string(forKey: Keys.turnUrl) ?? ""
        self.turnUsername = defaults.string(forKey: Keys.turnUsername) ?? ""
        self.turnPassword = defaults.string(forKey: Keys.turnPassword) ?? ""
        self.sdkLicenseKey = defaults.string(forKey: Keys.sdkLicenseKey) ?? ""
        self.appName = defaults.string(forKey: Keys.appName) ?? "live"
        self.nodeGroup = defaults.string(forKey: Keys.nodeGroup) ?? "default"
        self.streamName = defaults.string(forKey: Keys.streamName) ?? "myStream"
        self.userName = defaults.string(forKey: Keys.userName) ?? ""
        self.password = defaults.string(forKey: Keys.password) ?? ""
        self.pubnubPubKey = defaults.string(forKey: Keys.pubnubPubKey) ?? ""
        self.pubnubSubKey = defaults.string(forKey: Keys.pubnubSubKey) ?? ""
        
        let dtlsValue = defaults.string(forKey: Keys.dtlsSetup) ?? "actpass"
        self.dtlsSetup = DTLSSetup(rawValue: dtlsValue) ?? .actpass
    }
    
    // Static getter methods
    static func getStreamManagerHost() -> String {
        return shared.streamManagerHost
    }
    
    static func getStandaloneServerIp() -> String {
        return shared.standaloneServerIp
    }
    
    static func getStandaloneServerPort() -> Int {
        return shared.standaloneServerPort
    }
    
    static func getTurnUrl() -> String {
        return shared.turnUrl
    }
    
    static func getTurnUsername() -> String {
        return shared.turnUsername
    }
    
    static func getTurnPassword() -> String {
        return shared.turnPassword
    }
    
    static func getSdkLicenseKey() -> String {
        return shared.sdkLicenseKey
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
    
    static func getPubnubPubKey() -> String {
        return shared.pubnubPubKey
    }
    
    static func getPubnubSubKey() -> String {
        return shared.pubnubSubKey
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
        turnUrl = turnUrl.trimmingCharacters(in: .whitespaces)
        turnUsername = turnUsername.trimmingCharacters(in: .whitespaces)
        turnPassword = turnPassword.trimmingCharacters(in: .whitespaces)
        sdkLicenseKey = sdkLicenseKey.trimmingCharacters(in: .whitespaces)
        userName = userName.trimmingCharacters(in: .whitespaces)
        password = password.trimmingCharacters(in: .whitespaces)
        pubnubPubKey = pubnubPubKey.trimmingCharacters(in: .whitespaces)
        pubnubSubKey = pubnubSubKey.trimmingCharacters(in: .whitespaces)
        
        if appName.trimmingCharacters(in: .whitespaces).isEmpty {
            appName = "live"
        }
        if nodeGroup.trimmingCharacters(in: .whitespaces).isEmpty {
            nodeGroup = "default"
        }
        if streamName.trimmingCharacters(in: .whitespaces).isEmpty {
            streamName = "myStream"
        }
        if standaloneServerPort <= 0 {
            standaloneServerPort = 5080
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
