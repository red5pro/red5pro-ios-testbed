//
//  SettingsView.swift
//  SampleApp
//
//  Created by Mustafa BOLEKEN on 21.10.2025.
//

import SwiftUI

// MARK: - Settings Screen
struct SettingsScreen: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stream Manager Host")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter host", text: $settings.streamManagerHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Standalone Server IP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter IP", text: $settings.standaloneServerIp)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("Stream Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("live", text: $settings.appName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Node Group")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("default", text: $settings.nodeGroup)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stream Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("myStream", text: $settings.streamName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                
                Section(header: Text("Authentication")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter username", text: $settings.userName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter password", text: $settings.password)
                    }
                }
                
                Section(header: Text("DTLS Setup")) {
                    Picker("DTLS Mode", selection: $settings.dtlsSetup) {
                        ForEach(DTLSSetup.allCases, id: \.self) { setup in
                            Text(setup.displayName).tag(setup)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button(action: {
                        settings.saveSettings()
                        showingSaveAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Save Settings")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        settings.saveSettings()
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Settings saved successfully!")
            }
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsScreen()
    }
}
