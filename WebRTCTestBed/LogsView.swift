//
//  LogsView.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 11.11.2025.
//

import SwiftUI

// MARK: - Logs View
struct LogsView: View {
    @ObservedObject var logManager = LogManager.shared
    @State private var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @State private var searchText = ""
    @State private var showingExportSheet = false
    @State private var exportText = ""
    @State private var autoScroll = true
    @State private var showingFilters = false
    @Environment(\.dismiss) private var dismiss
    
    var filteredLogs: [LogEntry] {
        logManager.filteredLogs(
            levels: selectedLevels,
            categories: [],
            searchText: searchText
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Filter chips
                if showingFilters {
                    filterChips
                }
                
                // Logs list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredLogs) { log in
                                LogRowView(log: log)
                                    .id(log.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: logManager.logs.count) { _ in
                        if autoScroll, let lastLog = filteredLogs.last {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Bottom toolbar
                bottomToolbar
            }
            .navigationTitle("Logs (\(filteredLogs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation {
                                showingFilters.toggle()
                            }
                        }) {
                            Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: {
                            exportText = logManager.exportLogs()
                            showingExportSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            logManager.clear()
                        }) {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportLogsView(logsText: exportText)
            }
        }
    }
    
    // MARK: - UI Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search logs...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    FilterChip(
                        title: level.rawValue,
                        emoji: level.emoji,
                        isSelected: selectedLevels.contains(level)
                    ) {
                        if selectedLevels.contains(level) {
                            selectedLevels.remove(level)
                        } else {
                            selectedLevels.insert(level)
                        }
                    }
                }
                
                // Select/Deselect All
                Button(action: {
                    if selectedLevels.count == LogLevel.allCases.count {
                        selectedLevels.removeAll()
                    } else {
                        selectedLevels = Set(LogLevel.allCases)
                    }
                }) {
                    Text(selectedLevels.count == LogLevel.allCases.count ? "Deselect All" : "Select All")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }
    
    private var bottomToolbar: some View {
        HStack {
            Toggle(isOn: $autoScroll) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Auto-scroll")
                }
                .font(.caption)
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Spacer()
            
            Text("\(logManager.logs.count) total logs")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - Log Row View
struct LogRowView: View {
    let log: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // Level emoji
                Text(log.level.emoji)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Time and category
                    HStack(spacing: 8) {
                        Text(log.formattedTimestamp)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .monospaced()
                        
                        Text(log.category)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(for: log.level).opacity(0.2))
                            .foregroundColor(categoryColor(for: log.level))
                            .cornerRadius(4)
                    }
                    
                    // Message
                    Text(log.message)
                        .font(.caption)
                        .lineLimit(isExpanded ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(levelBackground(for: log.level))
            .cornerRadius(6)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    private func categoryColor(for level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .event: return .green
        }
    }
    
    private func levelBackground(for level: LogLevel) -> Color {
        switch level {
        case .debug: return Color(.systemGray6)
        case .info: return Color.blue.opacity(0.05)
        case .warning: return Color.orange.opacity(0.05)
        case .error: return Color.red.opacity(0.05)
        case .event: return Color.green.opacity(0.05)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(title)
            }
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Export Logs View
struct ExportLogsView: View {
    let logsText: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(logsText)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Export Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [logsText])
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    LogsView()
}
