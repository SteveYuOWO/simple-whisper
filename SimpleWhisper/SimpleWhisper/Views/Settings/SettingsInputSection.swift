import SwiftUI
import AVFoundation

struct SettingsInputSection: View {
    @Environment(AppState.self) private var appState
    @State private var microphones: [AVCaptureDevice] = []
    @State private var isMicrophoneGranted = false
    @State private var isAccessibilityGranted = false

    var body: some View {
        @Bindable var state = appState
        let lang = appState.appLanguage

        VStack(spacing: 6) {
            SettingsGroupCard {
                // Microphone Picker
                HStack {
                    Text(lang.microphone)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("", selection: $state.selectedMicrophone) {
                        Text("Default").tag("Default")
                        ForEach(microphones, id: \.uniqueID) { mic in
                            Text(mic.localizedName).tag(mic.uniqueID)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                .frame(height: DS.settingsRowHeight)
                .padding(.horizontal, DS.settingsHPadding)

                SettingsSeparator()

                // Microphone Permission
                HStack {
                    Text(lang.microphonePermission)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if isMicrophoneGranted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.success)
                                .font(.system(size: 13))
                            Text(lang.permissionGranted)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.success)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(lang.permissionNotGranted)
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                            Button(lang.requestPermission) {
                                Task {
                                    let granted = await AudioRecorder.requestMicrophonePermission()
                                    isMicrophoneGranted = granted
                                }
                            }
                            .font(.system(size: 12))
                            .buttonStyle(.borderedProminent)
                            .tint(Color.brand)
                        }
                    }
                }
                .frame(height: DS.settingsRowHeight)
                .padding(.horizontal, DS.settingsHPadding)

                SettingsSeparator()

                // Hotkey Display / Recorder
                if appState.isRecordingHotkey {
                    HStack {
                        Text(lang.hotkey)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        HStack(spacing: 8) {
                            Text(appState.pendingHotkeyModifiers.isEmpty
                                 ? lang.pressModifierKeys
                                 : appState.modifierDisplay(for: appState.pendingHotkeyModifiers))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(appState.pendingHotkeyModifiers.isEmpty ? Color.textSecondary : Color.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.brand, lineWidth: 1.5)
                                )

                            Button {
                                appState.confirmRecordingHotkey()
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(appState.pendingHotkeyModifiers.isEmpty ? Color.gray : Color.success, in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.pendingHotkeyModifiers.isEmpty)

                            Button {
                                appState.cancelRecordingHotkey()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.gray, in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)
                } else {
                    Button {
                        appState.startRecordingHotkey()
                    } label: {
                        HStack {
                            Text(lang.hotkey)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            HStack(spacing: 8) {
                                Text(appState.hotkeyDisplay)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 6))
                                Text(lang.holdToRecord)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(height: DS.settingsRowHeight)
                    .padding(.horizontal, DS.settingsHPadding)
                }

                SettingsSeparator()

                // Accessibility Permission
                HStack {
                    Text(lang.accessibilityPermission)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if isAccessibilityGranted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.success)
                                .font(.system(size: 13))
                            Text(lang.permissionGranted)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.success)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(lang.permissionNotGranted)
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                            Button(lang.openSystemSettings) {
                                HotkeyManager.requestAccessibility()
                            }
                            .font(.system(size: 12))
                            .buttonStyle(.borderedProminent)
                            .tint(Color.brand)
                        }
                    }
                }
                .frame(height: DS.settingsRowHeight)
                .padding(.horizontal, DS.settingsHPadding)
            }
        }
        .onAppear {
            microphones = AudioRecorder.availableMicrophones()
            isMicrophoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            isAccessibilityGranted = HotkeyManager.isAccessibilityGranted()
        }
        .onDisappear {
            if appState.isRecordingHotkey {
                appState.cancelRecordingHotkey()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isMicrophoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            isAccessibilityGranted = HotkeyManager.isAccessibilityGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if appState.isRecordingHotkey {
                appState.cancelRecordingHotkey()
            }
        }
    }
}
