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

            // Shortcut Card
            VStack(spacing: 14) {
                if appState.isRecordingHotkey {
                    // Recording mode header
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 8, height: 8)
                        Text(lang.recordingHotkey)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }

                    // Display area with brand border
                    VStack(spacing: 6) {
                        if !appState.hasPendingHotkey {
                            Text(lang.pressAnyKeys)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            Text(appState.hotkeyDisplayString(modifiers: appState.pendingHotkeyModifiers, keyCode: appState.pendingHotkeyKeyCode))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                    .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.brand, lineWidth: 2)
                    )

                    // Save / Cancel buttons
                    HStack(spacing: 12) {
                        Button {
                            appState.confirmRecordingHotkey()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(lang.save)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(!appState.hasPendingHotkey ? Color.textTertiary : .white)
                            .frame(height: 32)
                            .padding(.horizontal, 20)
                            .background(
                                !appState.hasPendingHotkey ? Color.bgTertiary : Color.success,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!appState.hasPendingHotkey)

                        Button {
                            appState.cancelRecordingHotkey()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(lang.cancel)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Color.textSecondary)
                            .frame(height: 32)
                            .padding(.horizontal, 20)
                            .background(Color.bgTertiary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Normal mode - title
                    Text(lang.hotkey)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Display area - clickable
                    Button {
                        appState.startRecordingHotkey()
                    } label: {
                        Text(appState.hotkeyDisplay)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.themeSeparator, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)

                    // Click to change hint
                    Text(lang.clickToChange)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
            .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: DS.settingsCardCornerRadius))

            // Test Input Card
            VStack(alignment: .leading, spacing: 10) {
                Text(lang.testInput)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                TextEditor(text: $state.testInputText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 120)
                    .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.themeSeparator, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if state.testInputText.isEmpty {
                            Text(lang.testInputPlaceholder)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
            .background(Color.bgPrimary, in: RoundedRectangle(cornerRadius: DS.settingsCardCornerRadius))
        }
        .onAppear {
            microphones = AudioRecorder.availableMicrophones()
            isMicrophoneGranted = AudioRecorder.microphonePermissionStatus() == .granted
            isAccessibilityGranted = HotkeyManager.isAccessibilityGranted()
        }
        .onDisappear {
            if appState.isRecordingHotkey {
                appState.cancelRecordingHotkey()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isMicrophoneGranted = AudioRecorder.microphonePermissionStatus() == .granted
            isAccessibilityGranted = HotkeyManager.isAccessibilityGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if appState.isRecordingHotkey {
                appState.cancelRecordingHotkey()
            }
        }
    }
}
