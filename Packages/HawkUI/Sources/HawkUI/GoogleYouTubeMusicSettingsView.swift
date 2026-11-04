import SwiftUI
import HawkCore
import HawkSources

/// Official settings view for Google authentication, YouTube Music library synchronization, and API transparency.
public struct GoogleYouTubeMusicSettingsView: View {
    @State private var syncManager = GoogleMusicSyncManager.shared
    @State private var showDisconnectAlert = false
    @State private var showClientIdSheet = false
    @State private var showErrorAlert = false
    @State private var customClientIdInput = ""
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    public init() {}

    public var body: some View {
        ZStack {
            HawkTheme.darkBackground.ignoresSafeArea()

            List {
                // MARK: 1. Account Status
                Section(header: Text("Connected Account").foregroundColor(HawkTheme.textSecondary)) {
                    if syncManager.isConnected {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(HawkTheme.primaryAccent.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(HawkTheme.primaryAccent)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(syncManager.accountEmail ?? "Google User")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(HawkTheme.textPrimary)
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Active Connection")
                                        .font(.caption)
                                        .foregroundColor(HawkTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if let lastSync = syncManager.lastSyncDate {
                            HStack {
                                Text("Last Synced")
                                Spacer()
                                Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundColor(HawkTheme.textSecondary)
                            }
                        }

                        Button(role: .destructive) {
                            showDisconnectAlert = true
                        } label: {
                            Label("Disconnect Google Account", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Bring your YouTube Music playlists and liked songs directly into HAWK.")
                                .font(.subheadline)
                                .foregroundColor(HawkTheme.textSecondary)

                            Button {
                                if syncManager.isConfiguredAndReady {
                                    signInWithGoogle()
                                } else {
                                    customClientIdInput = syncManager.configuredClientId ?? ""
                                    showClientIdSheet = true
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if isSigningIn {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: syncManager.isConfiguredAndReady ? "g.circle.fill" : "gearshape.fill")
                                            .font(.title3)
                                    }
                                    Text(syncManager.isConfiguredAndReady ? "Continue with Google" : "Configure Google Client ID")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(syncManager.isConfiguredAndReady ? HawkTheme.primaryAccent : HawkTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(syncManager.isConfiguredAndReady ? Color.clear : HawkTheme.primaryAccent, lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(isSigningIn)

                            // MARK: Client ID Status Card
                            switch syncManager.configurationState {
                            case .notConfigured:
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                        Text("Google Cloud iOS Client ID Required")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(HawkTheme.textPrimary)
                                    }
                                    Text("An authorized iOS Client ID registered for 'com.hawk.music' is required to authenticate with Google.")
                                        .font(.caption)
                                        .foregroundColor(HawkTheme.textSecondary)

                                    Button {
                                        customClientIdInput = ""
                                        showClientIdSheet = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "slider.horizontal.3")
                                            Text("Setup Client ID")
                                        }
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(HawkTheme.primaryAccent)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(HawkTheme.primaryAccent.opacity(0.15))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(12)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(12)

                            case .invalidFormat(let reason):
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "xmark.octagon.fill")
                                            .foregroundColor(.red)
                                        Text("Invalid Client ID Format")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(HawkTheme.textPrimary)
                                    }
                                    Text(reason)
                                        .font(.caption)
                                        .foregroundColor(HawkTheme.textSecondary)

                                    Button("Edit Client ID") {
                                        customClientIdInput = syncManager.configuredClientId ?? ""
                                        showClientIdSheet = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(HawkTheme.primaryAccent)
                                }
                                .padding(12)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(12)

                            case .schemeNotRegisteredInBuild(let expectedScheme, _):
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.yellow)
                                        Text("Build Update Required")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(HawkTheme.textPrimary)
                                    }
                                    Text("Reversed scheme '\(expectedScheme)' is not registered in this installed build's Info.plist. A new build configured with this Client ID in project.yml is required.")
                                        .font(.caption)
                                        .foregroundColor(HawkTheme.textSecondary)

                                    Button("View Configuration Instructions") {
                                        customClientIdInput = syncManager.configuredClientId ?? ""
                                        showClientIdSheet = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(HawkTheme.primaryAccent)
                                }
                                .padding(12)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(12)

                            case .ready(let clientId, let scheme, _):
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Client ID Ready & Registered")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(HawkTheme.textPrimary)
                                        Text(clientId)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(HawkTheme.textTertiary)
                                            .lineLimit(1)
                                        Text("Scheme: \(scheme)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(HawkTheme.textTertiary)
                                    }
                                    Spacer()
                                    Button("Edit") {
                                        customClientIdInput = syncManager.configuredClientId ?? ""
                                        showClientIdSheet = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(HawkTheme.primaryAccent)
                                }
                                .padding(10)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(10)
                            }

                            Button {
                                customClientIdInput = syncManager.configuredClientId ?? ""
                                showClientIdSheet = true
                            } label: {
                                Text("Developer Client ID Settings")
                                    .font(.caption)
                                    .foregroundColor(HawkTheme.textTertiary)
                                    .underline()
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // MARK: 2. Synchronization Controls
                if syncManager.isConnected {
                    Section(header: Text("Library Synchronization").foregroundColor(HawkTheme.textSecondary)) {
                        Toggle(isOn: Binding(
                            get: { syncManager.isAutoSyncEnabled },
                            set: { syncManager.isAutoSyncEnabled = $0 }
                        )) {
                            Label("Automatic Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .tint(HawkTheme.primaryAccent)

                        Button {
                            Task {
                                await syncManager.syncNow()
                            }
                        } label: {
                            HStack {
                                Label("Sync Now", systemImage: "arrow.clockwise")
                                Spacer()
                                if syncManager.isSyncing {
                                    ProgressView()
                                        .tint(HawkTheme.primaryAccent)
                                }
                            }
                        }
                        .disabled(syncManager.isSyncing)
                        .foregroundColor(HawkTheme.primaryAccent)

                        if let status = syncManager.syncStatusMessage {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(HawkTheme.textTertiary)
                        }
                    }
                }

                // MARK: 3. API Capabilities & Technical Limitations
                Section(header: Text("API Capabilities & Limitations").foregroundColor(HawkTheme.textSecondary)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Supported via YouTube Data API v3", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                        Text("• Authenticated account email and connection verification.\n• User's YouTube playlists and track metadata.\n• Liked music videos (filtered by Category 10 Music).\n• Audio stream matching via HAWK's high-fidelity resolver.")
                            .font(.caption)
                            .foregroundColor(HawkTheme.textSecondary)

                        Divider().padding(.vertical, 2)

                        Label("Unsupported / Service Limitations", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.orange)
                        Text("• Personalized algorithmic radios (Supermix, Discover Mix) are proprietary to YouTube Music and unavailable via standard YouTube Data API v3.\n• Direct YouTube video audio streams cannot be streamed directly from YouTube; tracks are matched with high-bitrate audio sources.")
                            .font(.caption)
                            .foregroundColor(HawkTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Google & YouTube Music")
        .alert("Disconnect Account?", isPresented: $showDisconnectAlert) {
            Button("Disconnect", role: .destructive) {
                Task {
                    await syncManager.disconnect()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Disconnecting will remove saved Google credentials from Keychain. Your already-synced local playlists will remain in your library.")
        }
        .alert("Google Authentication", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
            if !syncManager.isConfiguredAndReady {
                Button("Configure Client ID") {
                    customClientIdInput = syncManager.configuredClientId ?? ""
                    showClientIdSheet = true
                }
            }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred during Google sign-in.")
        }
        .sheet(isPresented: $showClientIdSheet) {
            clientIdSheetContent
        }
    }

    private var clientIdSheetContent: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Google Cloud Client ID")
                            .font(.headline)
                            .foregroundColor(HawkTheme.textPrimary)

                        Text("Configure your native iOS OAuth Client ID created in Google Cloud Console. HAWK strictly enforces RFC 8252 PKCE with no client secrets.")
                            .font(.caption)
                            .foregroundColor(HawkTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("iOS Client ID")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(HawkTheme.textSecondary)

                            TextField("e.g. 123456789012-abc.apps.googleusercontent.com", text: $customClientIdInput)
                                .padding()
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(10)
                                .foregroundColor(HawkTheme.textPrimary)
                                .autocorrectionDisabled()
#if os(iOS)
                                .textInputAutocapitalization(.never)
#endif
                        }

                        // Live Validation & Scheme Status
                        let inputTrimmed = customClientIdInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !inputTrimmed.isEmpty {
                            let validation = GoogleMusicSyncManager.validateClientIdFormat(inputTrimmed)
                            switch validation {
                            case .failure(let err):
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(err.description)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(10)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(8)

                            case .success(let validId):
                                let scheme = GoogleMusicSyncManager.reversedScheme(for: validId)
                                let redirect = GoogleMusicSyncManager.redirectUri(for: validId)
                                let isRegistered = GoogleMusicSyncManager.isSchemeRegisteredInBundle(scheme)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(isRegistered ? .green : .yellow)
                                        Text(isRegistered ? "Reversed Scheme Registered in Build" : "Reversed Scheme Not Registered in Build")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(isRegistered ? .green : .yellow)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Expected Reversed Scheme:")
                                            .font(.caption2)
                                            .foregroundColor(HawkTheme.textTertiary)
                                        Text(scheme)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(HawkTheme.primaryAccent)

                                        Text("Redirect URI:")
                                            .font(.caption2)
                                            .foregroundColor(HawkTheme.textTertiary)
                                            .padding(.top, 2)
                                        Text(redirect)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(HawkTheme.primaryAccent)
                                    }

                                    if !isRegistered {
                                        Text("iOS requires this custom scheme to be compiled into Info.plist (CFBundleURLTypes). To use this Client ID, rebuild HAWK with this Client ID in project.yml.")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                            .padding(.top, 2)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HawkTheme.cardBackground.opacity(0.8))
                                .cornerRadius(8)
                            }
                        }

                        // Step-by-Step Google Cloud Console Checklist
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Setup in Google Cloud Console:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(HawkTheme.textPrimary)

                            checklistRow(number: "1", text: "Go to console.cloud.google.com and select your project.")
                            checklistRow(number: "2", text: "Enable 'YouTube Data API v3' in APIs & Services.")
                            checklistRow(number: "3", text: "Configure OAuth Consent Screen (add your email to Test Users).")
                            checklistRow(number: "4", text: "Go to Credentials → Create Credentials → OAuth Client ID.")
                            checklistRow(number: "5", text: "Select Application Type: iOS.")
                            checklistRow(number: "6", text: "Set Bundle ID: com.hawk.music")
                            checklistRow(number: "7", text: "Copy the Client ID and paste it above.")
                        }
                        .padding(12)
                        .background(HawkTheme.cardBackground)
                        .cornerRadius(10)

                        HStack(spacing: 12) {
                            Button("Save Client ID") {
                                syncManager.setCustomClientId(customClientIdInput)
                                showClientIdSheet = false
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(HawkTheme.primaryAccent)
                            .cornerRadius(12)
                            .disabled(inputTrimmed.isEmpty)

                            if syncManager.configuredClientId != nil {
                                Button("Clear") {
                                    syncManager.setCustomClientId(nil)
                                    customClientIdInput = ""
                                    showClientIdSheet = false
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .frame(height: 48)
                                .padding(.horizontal, 16)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showClientIdSheet = false }
                        .foregroundColor(HawkTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func checklistRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(HawkTheme.primaryAccent.opacity(0.2))
                    .frame(width: 20, height: 20)
                Text(number)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(HawkTheme.primaryAccent)
            }
            Text(text)
                .font(.caption)
                .foregroundColor(HawkTheme.textSecondary)
        }
    }

    private func signInWithGoogle() {
        isSigningIn = true
        errorMessage = nil
        Task {
            do {
                try await syncManager.startGoogleSignIn()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            isSigningIn = false
        }
    }
}
