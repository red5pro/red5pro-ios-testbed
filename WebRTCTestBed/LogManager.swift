//
//  LogManager.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 11.11.2025.
//

import Foundation
internal import Combine

// MARK: - Log Entry Model
struct LogEntry: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    
    init(level: LogLevel, category: String, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var displayText: String {
        "[\(formattedTimestamp)] [\(level.emoji) \(level.rawValue)] [\(category)] \(message)"
    }
}

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case event = "EVENT"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .event: return "📡"
        }
    }
    
    var color: String {
        switch self {
        case .debug: return "gray"
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        case .event: return "green"
        }
    }
}

// MARK: - Log Manager
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    @Published var isEnabled: Bool = true
    
    private let maxLogCount = 1000 // Keep last 1000 logs
    private let queue = DispatchQueue(label: "com.red5pro.logmanager", qos: .utility)
    
    private init() {
        // Log system started
        log(.info, category: "System", message: "Log Manager initialized")
    }
    
    // MARK: - Public Methods
    
    func log(_ level: LogLevel, category: String, message: String) {
        guard isEnabled else { return }
        
        queue.async {
            let entry = LogEntry(level: level, category: category, message: message)
            
            // Also print to console for debugging
            print("[\(entry.formattedTimestamp)] [\(level.rawValue)] [\(category)] \(message)")
            
            DispatchQueue.main.async {
                self.logs.append(entry)
                
                // Trim logs if exceeding max count
                if self.logs.count > self.maxLogCount {
                    self.logs.removeFirst(self.logs.count - self.maxLogCount)
                }
            }
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
}
