//
//  SettingsView.swift
//  WebRTCTestBed
//
//  Created by Mustafa BOLEKEN on 21.10.2025.
//

import SwiftUI
import Red5WebRTCKit

// MARK: - Settings Screen
struct SettingsScreen: View {
    @StateObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveAlert = false
    @State private var showingLogs = false

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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Standalone Server Port")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("5080", text: Binding(
                            get: { String(settings.standaloneServerPort) },
                            set: { settings.standaloneServerPort = Int($0) ?? 5080 }
                        ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.numberPad)
                    }
                }

                Section(header: Text("Turn Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Turn URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter url", text: $settings.turnUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Turn Username")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter username", text: $settings.turnUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Turn Password")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter password", text: $settings.turnPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                }

                Section(header: Text("SDK Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SDK License Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter license key", text: $settings.sdkLicenseKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
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

                Section(header: Text("PubNub Credentials")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Channel Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter channel name", text: $settings.pubnubChannel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Publish Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter publish key", text: $settings.pubnubPubKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subscribe Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter subscribe key", text: $settings.pubnubSubKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter token", text: $settings.pubnubToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
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

                Section(header: Text("Build Configuration")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SDK Version: \(Red5WebrtcClientConfig.getVersion())")
                        Text("License Manager: \(BuildConfig.licenseManager)")
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLogs = true
                    }) {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
            }
            .sheet(isPresented: $showingLogs) {
                LogsView()
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
