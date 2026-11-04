import SwiftUI
import HawkCore
import HawkSources

/// Official settings view for Google authentication, YouTube Music library synchronization, and API transparency.
public struct GoogleYouTubeMusicSettingsView: View {
    @State private var syncManager = GoogleMusicSyncManager.shared
    @State private var showDisconnectAlert = false
    @State private var showManualTokenSheet = false
    @State private var showClientIdSheet = false
    @State private var showErrorAlert = false
    @State private var manualEmail = ""
    @State private var manualToken = ""
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
                                signInWithGoogle()
                            } label: {
                                HStack(spacing: 10) {
                                    if isSigningIn {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "g.circle.fill")
                                            .font(.title3)
                                    }
                                    Text("Continue with Google")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(HawkTheme.primaryAccent)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .disabled(isSigningIn)

                            // Client ID Status & Configuration Card
                            if syncManager.isUsingDefaultPlaceholder {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.orange)
                                        Text("Google Cloud iOS Client ID")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(HawkTheme.textPrimary)
                                    }
                                    Text("To sign in on physical devices, configure your Google Cloud iOS Client ID registered for 'com.hawk.music'.")
                                        .font(.caption)
                                        .foregroundColor(HawkTheme.textSecondary)

                                    Button {
                                        customClientIdInput = syncManager.customClientId ?? ""
                                        showClientIdSheet = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "slider.horizontal.3")
                                            Text("Configure Client ID")
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
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Custom Client ID Active")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(HawkTheme.textPrimary)
                                        Text(syncManager.effectiveClientId)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(HawkTheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button("Edit") {
                                        customClientIdInput = syncManager.customClientId ?? ""
                                        showClientIdSheet = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(HawkTheme.primaryAccent)
                                }
                                .padding(10)
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(10)
                            }

                            HStack(spacing: 16) {
                                Button {
                                    showClientIdSheet = true
                                } label: {
                                    Text("OAuth Settings")
                                        .font(.caption)
                                        .foregroundColor(HawkTheme.textTertiary)
                                        .underline()
                                }

                                Button {
                                    showManualTokenSheet = true
                                } label: {
                                    Text("Manual Token Input")
                                        .font(.caption)
                                        .foregroundColor(HawkTheme.textTertiary)
                                        .underline()
                                }
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

                // MARK: 3. Music Scope & API Disclosure
                Section(header: Text("Data Scope & Privacy").foregroundColor(HawkTheme.textSecondary)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Strict Music-Only Scope", systemImage: "checkmark.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HawkTheme.textPrimary)
                        Text("HAWK only accesses your music playlists and liked songs. It never accesses your watch history, video subscriptions, channels, or personal comments.")
                            .font(.caption)
                            .foregroundColor(HawkTheme.textSecondary)

                        Divider().padding(.vertical, 4)

                        Label("Supported Audio Matching", systemImage: "info.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HawkTheme.textPrimary)
                        Text("Imported tracks are stored as genuine library records. When streamed, HAWK matches each track with playable high-bitrate sources. Tracks without accessible sources display an explicit unavailable badge.")
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
            if syncManager.isUsingDefaultPlaceholder {
                Button("Configure Client ID") {
                    customClientIdInput = syncManager.customClientId ?? ""
                    showClientIdSheet = true
                }
            }
        } message: {
            Text(errorMessage ?? "An unexpected error occurred during Google sign-in.")
        }
        .sheet(isPresented: $showManualTokenSheet) {
            manualTokenSheetContent
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

                        Text("Configure your native iOS OAuth Client ID created in Google Cloud Console. HAWK uses RFC 8252 PKCE without requiring any client secrets.")
                            .font(.caption)
                            .foregroundColor(HawkTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("iOS Client ID")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(HawkTheme.textSecondary)

                            TextField("e.g. 123456-abc.apps.googleusercontent.com", text: $customClientIdInput)
                                .padding()
                                .background(HawkTheme.cardBackground)
                                .cornerRadius(10)
                                .foregroundColor(HawkTheme.textPrimary)
                                .autocorrectionDisabled()
#if os(iOS)
                                .textInputAutocapitalization(.never)
#endif
                        }

                        // Derived Dynamic OAuth Configuration Preview
                        let previewId = customClientIdInput.trimmingCharacters(in: .whitespaces).isEmpty ? syncManager.effectiveClientId : customClientIdInput.trimmingCharacters(in: .whitespaces)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Derived RFC 8252 OAuth Configuration:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(HawkTheme.textPrimary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reversed Callback Scheme:")
                                    .font(.caption2)
                                    .foregroundColor(HawkTheme.textTertiary)
                                Text(GoogleMusicSyncManager.reversedScheme(for: previewId))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(HawkTheme.primaryAccent)

                                Text("Redirect URI:")
                                    .font(.caption2)
                                    .foregroundColor(HawkTheme.textTertiary)
                                    .padding(.top, 2)
                                Text(GoogleMusicSyncManager.redirectUri(for: previewId))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(HawkTheme.primaryAccent)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HawkTheme.cardBackground.opacity(0.6))
                            .cornerRadius(8)
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

                            if syncManager.customClientId != nil {
                                Button("Reset Default") {
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

    private var manualTokenSheetContent: some View {
        NavigationStack {
            ZStack {
                HawkTheme.darkBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Manual Token Input")
                        .font(.headline)
                        .foregroundColor(HawkTheme.textPrimary)
                        .padding(.top, 10)

                    Text("Enter your Google Account email and YouTube Data API bearer token or cookie credentials.")
                        .font(.caption)
                        .foregroundColor(HawkTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    TextField("Account Email", text: $manualEmail)
                        .padding()
                        .background(HawkTheme.cardBackground)
                        .cornerRadius(10)
                        .foregroundColor(HawkTheme.textPrimary)
                        .padding(.horizontal)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif

                    SecureField("Access Token / Authorization Header", text: $manualToken)
                        .padding()
                        .background(HawkTheme.cardBackground)
                        .cornerRadius(10)
                        .foregroundColor(HawkTheme.textPrimary)
                        .padding(.horizontal)

                    Button("Save and Connect") {
                        Task {
                            guard !manualEmail.isEmpty && !manualToken.isEmpty else { return }
                            try? await syncManager.connectWithToken(email: manualEmail, accessToken: manualToken)
                            showManualTokenSheet = false
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(HawkTheme.primaryAccent)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showManualTokenSheet = false }
                        .foregroundColor(HawkTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
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
