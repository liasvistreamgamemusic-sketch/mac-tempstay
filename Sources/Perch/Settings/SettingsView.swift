import AppKit
import SwiftUI

/// The preferences window: shelf placement & behaviour, shortcuts, startup, and
/// updates. Binds directly to `SettingsStore`, so edits persist immediately and
/// every subsystem observing the store reacts.
struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var hotkeys: HotkeyBindingManager

    /// Re-apply settings-derived state (edge position, edge trigger).
    var onShelfSettingsChanged: () -> Void
    /// Toggle the login item; returns whether it succeeded.
    var onLaunchAtLoginChanged: (Bool) -> Void
    /// User asked to check for updates now.
    var onCheckForUpdates: () -> Void

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("一般", systemImage: "slider.horizontal.3") }
            shortcutsTab
                .tabItem { Label("ショートカット", systemImage: "command") }
            aboutTab
                .tabItem { Label("情報", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 380)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("シェルフ") {
                Picker("表示位置", selection: edgeBinding) {
                    ForEach(ShelfEdge.allCases) { edge in
                        Text(edge.title).tag(edge)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("端へのドラッグで自動表示", isOn: revealBinding)
                Toggle("操作後に自動的に隠す", isOn: autoHideBinding)

                if settingsStore.settings.autoHide {
                    HStack {
                        Text("隠すまでの時間")
                        Slider(value: autoHideDelayBinding, in: 0.5...5.0, step: 0.5)
                        Text(String(format: "%.1f秒", settingsStore.settings.autoHideDelay))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Section("アイテム") {
                Toggle("アプリ終了後もアイテムを保持", isOn: persistBinding)
            }

            Section("起動") {
                Toggle("ログイン時に起動", isOn: launchAtLoginBinding)
                if LaunchAtLogin.requiresApproval {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                        Text("システム設定のログイン項目で承認が必要です。")
                            .font(.caption)
                        Button("開く") { LaunchAtLogin.openSystemSettings() }
                            .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { action in
                    HStack {
                        Label(action.title, systemImage: action.symbolName)
                        Spacer()
                        HotkeyRecorderField(combo: comboBinding(for: action)) { _ in
                            hotkeys.refresh()
                        }
                        .frame(width: 130, height: 24)
                    }
                    if hotkeys.unboundActions.contains(action) {
                        Text("このショートカットは登録できませんでした（他のアプリと競合している可能性があります）。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } footer: {
                Text("⌘ または ⌃ を含む組み合わせのみ登録できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text(AppInfo.name)
                .font(.title2.weight(.semibold))
            Text("バージョン \(AppInfo.version) (\(AppInfo.build))")
                .foregroundStyle(.secondary)
            Text("ドラッグ中のファイルを一時的に置いておける\n画面端のシェルフ。")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("アップデートを確認", action: onCheckForUpdates)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }

    // MARK: - Bindings

    private var edgeBinding: Binding<ShelfEdge> {
        Binding(
            get: { settingsStore.settings.edge },
            set: { newValue in settingsStore.update { $0.edge = newValue }; onShelfSettingsChanged() }
        )
    }

    private var revealBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.revealOnDragToEdge },
            set: { newValue in settingsStore.update { $0.revealOnDragToEdge = newValue }; onShelfSettingsChanged() }
        )
    }

    private var autoHideBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.autoHide },
            set: { newValue in settingsStore.update { $0.autoHide = newValue } }
        )
    }

    private var autoHideDelayBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.autoHideDelay },
            set: { newValue in settingsStore.update { $0.autoHideDelay = newValue } }
        )
    }

    private var persistBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.persistItemsAcrossLaunches },
            set: { newValue in settingsStore.update { $0.persistItemsAcrossLaunches = newValue } }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.launchAtLogin },
            set: { newValue in
                settingsStore.update { s in s.launchAtLogin = newValue }
                onLaunchAtLoginChanged(newValue)
            }
        )
    }

    private func comboBinding(for action: HotkeyAction) -> Binding<KeyCombo> {
        Binding(
            get: { settingsStore.shortcut(for: action) },
            set: { newCombo in settingsStore.update { s in s.shortcuts[action] = newCombo } }
        )
    }
}
