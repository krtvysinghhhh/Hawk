import SwiftUI
import HawkCore
import HawkSources

/// Official settings view for Google authentication, YouTube Music library synchronization, and API transparency.
public struct GoogleYouTubeMusicSettingsView: View {
    @State private var syncManager = GoogleMusicSyncManager.shared
    @State private var showDisconnectAlert = false
    @State private var showManualTokenSheet = false
    @State private var manualEmail = ""
    @State private var manualToken = ""
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
                        VStack(alignment: .leading, spacing: 12) {
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

                            Button {
                                showManualTokenSheet = true
                            } label: {
                                Text("Advanced / Custom Token Connection")
                                    .font(.caption)
                                    .foregroundColor(HawkTheme.textTertiary)
                                    .underline()
                            }
                            .padding(.top, 4)
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
        .sheet(isPresented: $showManualTokenSheet) {
            manualTokenSheetContent
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
            }
            isSigningIn = false
        }
    }
}
