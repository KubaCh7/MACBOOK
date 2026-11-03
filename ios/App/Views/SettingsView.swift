import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("theme", store: L.defaults) private var theme = "system"
    @AppStorage("sounds", store: L.defaults) private var sounds = true
    @State private var name = ""
    @State private var savedStamp = false
    @State private var confirmDelete = false
    @State private var exportURL: URL?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                UpdateBanner()

                section(L.t("profile")) {
                    LabeledField(label: L.t("name")) { TextField("", text: $name).textContentType(.givenName) }
                    if store.mode == .remote {
                        Text(store.email).font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Button(savedStamp ? L.t("savedStamp") : L.t("save")) {
                        store.setDisplayName(name.trimmingCharacters(in: .whitespaces))
                        Sound.shared.click()
                        savedStamp = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedStamp = false }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                section(L.t("appearance")) {
                    Text(L.t("language")).font(.system(size: 14, weight: .medium))
                    LanguagePicker()
                    Text(L.t("theme")).font(.system(size: 14, weight: .medium))
                    Picker(L.t("theme"), selection: $theme) {
                        Text(L.t("themeSystem")).tag("system")
                        Text(L.t("themeLight")).tag("light")
                        Text(L.t("themeDark")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $sounds) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("sounds")).font(.system(size: 15, weight: .medium))
                            Text(L.t("soundsDesc")).font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                    .tint(Theme.primary)
                    .onChange(of: sounds) { _, on in if on { Sound.shared.coin() } }
                }

                section(L.t("data")) {
                    if store.mode == .remote {
                        if store.syncing {
                            Text(L.t("syncing")).font(.system(size: 13)).foregroundStyle(Theme.muted)
                        } else if let err = store.syncError {
                            Text(err).font(.system(size: 13)).foregroundStyle(Theme.negative)
                        } else if let last = store.lastSync {
                            Text(L.t("lastSync", ["time": last.formatted(date: .omitted, time: .shortened)]))
                                .font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                        Button(L.t("syncNow")) { Task { await store.syncNow() } }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if let exportURL {
                        ShareLink(item: exportURL) { SecondaryLabel(text: L.t("exportJson")) }
                    } else {
                        Button(L.t("exportJson")) { exportURL = store.exportJSON() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }

                section(L.t("documents")) {
                    NavigationLink { LegalView(doc: .privacy) } label: { linkRow(L.t("privacy")) }
                    Divider().overlay(Theme.rule)
                    NavigationLink { LegalView(doc: .terms) } label: { linkRow(L.t("terms")) }
                    Divider().overlay(Theme.rule)
                    NavigationLink { LegalView(doc: .info) } label: { linkRow(L.t("info")) }
                }

                section(L.t("account")) {
                    if store.mode == .remote {
                        Button(L.t("signOut")) { store.signOut() }.buttonStyle(SecondaryButtonStyle())
                    } else {
                        Text(L.t("localDesc")).font(.system(size: 13)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if store.canUseAccounts {
                            Button(L.t("createAccount")) { store.signOut() }.buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    Button(store.mode == .remote ? L.t("deleteAccount") : L.t("deleteLocal")) { confirmDelete = true }
                        .buttonStyle(SecondaryButtonStyle(destructive: true))
                    if let error { Text(error).font(.system(size: 13)).foregroundStyle(Theme.negative) }
                }

                Text("\(L.t("appName")) · \(L.t("version")) \(store.currentBuild)")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .screenBackground()
        .navigationTitle(L.t("tabSettings"))
        .onAppear { name = store.displayName; exportURL = nil }
        .confirmationDialog(L.t("deleteAccountQ"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L.t("delete"), role: .destructive) {
                Task {
                    do { try await store.deleteAccount(); Sound.shared.remove() } catch { self.error = error.localizedDescription }
                }
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        Card {
            CardTitle(text: title)
            content()
        }
    }

    private func linkRow(_ text: String) -> some View {
        HStack {
            Text(text).foregroundStyle(Theme.text)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .font(.system(size: 15))
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
