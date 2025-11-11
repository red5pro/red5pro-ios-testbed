//
//  LogManager.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 11.11.2025.
//

import Foundation
internal import Combine
import OSLog

// MARK: - Log Entry Model
struct LogEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let subsystem: String?
    let processID: Int?
    let threadID: UInt64?
    
    init(level: LogLevel, category: String, message: String, subsystem: String? = nil, processID: Int? = nil, threadID: UInt64? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.subsystem = subsystem
        self.processID = processID
        self.threadID = threadID
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var displayText: String {
        var text = "[\(formattedTimestamp)] [\(level.rawValue)] [\(category)]"
        if let subsystem = subsystem {
            text += " [\(subsystem)]"
        }
        text += " \(message)"
        return text
    }
    
    var detailedText: String {
        var text = displayText
        if let pid = processID {
            text += "\n  PID: \(pid)"
        }
        if let tid = threadID {
            text += "\n  Thread: \(tid)"
        }
        return text
    }
}

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case event = "EVENT"
    case system = "SYSTEM"
    
    var color: String {
        switch self {
        case .debug: return "gray"
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        case .event: return "green"
        case .system: return "purple"
        }
    }
}

// MARK: - Log Manager
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    @Published var isEnabled: Bool = true
    @Published var isSystemLogsEnabled: Bool = false {
        didSet {
            if isSystemLogsEnabled {
                startSystemLogCapture()
            } else {
                stopSystemLogCapture()
            }
        }
    }
    
    private let maxLogCount = 2000 // Increased to accommodate system logs
    private let queue = DispatchQueue(label: "com.red5pro.logmanager", qos: .utility)
    
    // System log capture
    private var systemLogStore: OSLogStore?
    private var systemLogTimer: Timer?
    private var lastSystemLogPosition: OSLogPosition?
    private let systemLogQueue = DispatchQueue(label: "com.red5pro.systemlogs", qos: .utility)
    
    // App identifier for filtering
    private let appBundleIdentifier: String
    private let appProcessIdentifier: Int32
    
    private init() {
        self.appBundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
        self.appProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        
        // Log system started
        log(.info, category: "System", message: "Log Manager initialized")
        
        // Setup system log store
        setupSystemLogStore()
    }
    
    // MARK: - System Log Capture
    
    private func setupSystemLogStore() {
        do {
            systemLogStore = try OSLogStore(scope: .currentProcessIdentifier)
            log(.info, category: "SystemLogs", message: "System log store initialized")
        } catch {
            log(.error, category: "SystemLogs", message: "Failed to initialize system log store: \(error.localizedDescription)")
        }
    }
    
    func startSystemLogCapture() {
        guard systemLogStore != nil else {
            log(.error, category: "SystemLogs", message: "System log store not available")
            return
        }
        
        log(.info, category: "SystemLogs", message: "Starting system log capture")
        
        // Get current position
        systemLogQueue.async { [weak self] in
            self?.captureRecentSystemLogs()
            
            // Start periodic polling
            DispatchQueue.main.async {
                self?.systemLogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.systemLogQueue.async {
                        self?.captureNewSystemLogs()
                    }
                }
            }
        }
    }
    
    func stopSystemLogCapture() {
        log(.info, category: "SystemLogs", message: "Stopping system log capture")
        systemLogTimer?.invalidate()
        systemLogTimer = nil
        lastSystemLogPosition = nil
    }
    
    private func captureRecentSystemLogs() {
        guard let store = systemLogStore else { return }
        
        do {
            // Get logs from the last 10 seconds
            let timeInterval: TimeInterval = -10
            let startDate = Date(timeIntervalSinceNow: timeInterval)
            
            let position = store.position(date: startDate)
            let entries = try store.getEntries(at: position)
            
            var count = 0
            for entry in entries {
                if count >= 100 { break } // Limit initial batch
                
                if let logEntry = entry as? OSLogEntryLog {
                    processSystemLogEntry(logEntry)
                    count += 1
                }
            }
            
            // Store the last position
            lastSystemLogPosition = try store.position(date: Date())
            
            DispatchQueue.main.async {
                self.log(.info, category: "SystemLogs", message: "Captured \(count) recent system log entries")
            }
        } catch {
            DispatchQueue.main.async {
                self.log(.error, category: "SystemLogs", message: "Failed to capture recent logs: \(error.localizedDescription)")
            }
        }
    }
    
    private func captureNewSystemLogs() {
        guard let store = systemLogStore else { return }
        
        do {
            let position = lastSystemLogPosition ?? store.position(timeIntervalSinceLatestBoot: 0)
            let entries = try store.getEntries(at: position)
            
            var newEntries: [OSLogEntryLog] = []
            for entry in entries {
                if let logEntry = entry as? OSLogEntryLog {
                    newEntries.append(logEntry)
                }
            }
            
            // Process new entries
            for logEntry in newEntries {
                processSystemLogEntry(logEntry)
            }
            
            // Update position
            if !newEntries.isEmpty {
                lastSystemLogPosition = try store.position(date: Date())
            }
        } catch {
            // Silently fail to avoid spam
        }
    }
    
    private func processSystemLogEntry(_ entry: OSLogEntryLog) {
        // Convert OSLogEntryLog.Level to our LogLevel
        let level: LogLevel
        switch entry.level {
        case .debug:
            level = .debug
        case .info:
            level = .info
        case .notice:
            level = .info
        case .error:
            level = .error
        case .fault:
            level = .error
        default:
            level = .system
        }
        
        let logEntry = LogEntry(
            level: level,
            category: entry.category,
            message: entry.composedMessage,
            subsystem: entry.subsystem,
            processID: Int(entry.process),
            threadID: entry.threadIdentifier
        )
        
        DispatchQueue.main.async {
            self.addLogEntry(logEntry)
        }
    }
    
    private func addLogEntry(_ entry: LogEntry) {
        logs.append(entry)
        
        // Trim logs if exceeding max count
        if logs.count > maxLogCount {
            logs.removeFirst(logs.count - maxLogCount)
        }
    }
    
    // MARK: - Public Methods
    
    func log(_ level: LogLevel, category: String, message: String) {
        guard isEnabled else { return }
        
        queue.async {
            let entry = LogEntry(
                level: level,
                category: category,
                message: message,
                subsystem: self.appBundleIdentifier,
                processID: Int(self.appProcessIdentifier),
                threadID: UInt64(pthread_mach_thread_np(pthread_self()))
            )
            
            // Also print to console for debugging
            print("[\(entry.formattedTimestamp)] [\(level.rawValue)] [\(category)] \(message)")
            
            // Log to OSLog as well
            self.logToOSLog(level: level, category: category, message: message)
            
            DispatchQueue.main.async {
                self.addLogEntry(entry)
            }
        }
    }
    
    private func logToOSLog(level: LogLevel, category: String, message: String) {
        let logger = Logger(subsystem: appBundleIdentifier, category: category)
        
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info, .event:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .system:
            logger.notice("\(message)")
        }
    }
    
    func debug(_ category: String, _ message: String) {
        log(.debug, category: category, message: message)
    }
    
    func info(_ category: String, _ message: String) {
        log(.info, category: category, message: message)
    }
    
    func warning(_ category: String, _ message: String) {
        log(.warning, category: category, message: message)
    }
    
    func error(_ category: String, _ message: String) {
        log(.error, category: category, message: message)
    }
    
    func event(_ category: String, _ message: String) {
        log(.event, category: category, message: message)
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.log(.info, category: "System", message: "Logs cleared")
        }
    }
    
    func exportLogs() -> String {
        logs.map { $0.displayText }.joined(separator: "\n")
    }
    
    func filteredLogs(levels: Set<LogLevel>, categories: Set<String>, searchText: String) -> [LogEntry] {
        logs.filter { entry in
            let levelMatch = levels.isEmpty || levels.contains(entry.level)
            let categoryMatch = categories.isEmpty || categories.contains(entry.category)
            let searchMatch = searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText)
            return levelMatch && categoryMatch && searchMatch
        }
    }
    
    // Get all unique categories
    func getAllCategories() -> [String] {
        Array(Set(logs.map { $0.category })).sorted()
    }
    
    // Get all unique subsystems
    func getAllSubsystems() -> [String] {
        Array(Set(logs.compactMap { $0.subsystem })).sorted()
    }
}
