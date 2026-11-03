import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.scenePhase) private var phase
    @AppStorage("lang", store: L.defaults) private var lang = "pl"
    @AppStorage("theme", store: L.defaults) private var theme = "system"
    @Query(sort: \GoalEntity.createdAt) private var allGoals: [GoalEntity]

    private var goals: [GoalEntity] { allGoals.filter { $0.deletedAt == nil } }

    private var scheme: ColorScheme? {
        theme == "light" ? .light : theme == "dark" ? .dark : nil
    }

    var body: some View {
        Group {
            if store.mode == .signedOut {
                NavigationStack { AuthView() }
            } else if goals.isEmpty {
                NavigationStack { OnboardingView() }
            } else {
                MainTabs(goals: goals)
            }
        }
        .id(lang)
        .preferredColorScheme(scheme)
        .tint(Theme.primary)
        .task {
            store.refreshWidget()
            await store.syncNow()
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active { Task { await store.syncNow() } }
        }
        .task(id: store.mode) {
            // dane z innych urządzeń odświeżają się same, co 30 s gdy aplikacja jest otwarta
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if phase == .active { await store.syncNow() }
            }
        }
    }
}

struct MainTabs: View {
    let goals: [GoalEntity]
    @EnvironmentObject var store: AppStore
    @State private var tab = 0
    @State private var goalID: UUID?

    private var current: GoalEntity {
        goals.first(where: { $0.id == goalID }) ?? goals.first(where: { $0.isDefault }) ?? goals[0]
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { OverviewView(goal: current, goals: goals, goalID: $goalID) }
                .tabItem { Label(L.t("tabStart"), image: "Laptop") }
                .tag(0)
            NavigationStack { DepositsView(goal: current, goals: goals, goalID: $goalID) }
                .tabItem { Label(L.t("tabDeposits"), systemImage: "arrow.up.arrow.down") }
                .tag(1)
            NavigationStack { GoalsView(goals: goals, onOpen: { id in goalID = id; tab = 0 }) }
                .tabItem { Label(L.t("tabGoals"), systemImage: "flag") }
                .tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label(L.t("tabSettings"), systemImage: "slider.horizontal.3") }
                .tag(3)
        }
        .tint(Theme.primary)
        .onChange(of: tab) { _, _ in Sound.shared.tab() }
    }
}

/// Przełącznik celu w pasku nawigacji (gdy celów jest więcej niż jeden).
struct GoalSwitcher: View {
    let goals: [GoalEntity]
    @Binding var goalID: UUID?
    let current: GoalEntity

    var body: some View {
        if goals.count > 1 {
            Menu {
                ForEach(goals) { g in
                    Button {
                        goalID = g.id
                        Sound.shared.tab()
                    } label: {
                        if g.id == current.id { Label(g.name, systemImage: "checkmark") } else { Text(g.name) }
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
            }
            .accessibilityLabel(L.t("tabGoals"))
        }
    }
}

/// Baner aktualizacji: nowa wersja w app_config.ios_update.latest_build > APP_BUILD.
struct UpdateBanner: View {
    @EnvironmentObject var store: AppStore
    @State private var copied = false
    static let command = "cd ~/Documents/MACBOOK && git checkout -- . && git pull"

    var body: some View {
        if store.updateAvailable {
            Card {
                Text(L.t("updateTitle")).font(.system(size: 16, weight: .semibold))
                Text(L.t("updateBody")).font(.system(size: 14)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                Text(Self.command)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
                Button(copied ? L.t("copied") : L.t("copy")) {
                    UIPasteboard.general.string = Self.command
                    copied = true
                    Sound.shared.click()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}
