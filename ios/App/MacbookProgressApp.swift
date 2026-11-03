import SwiftData
import SwiftUI

@main
struct MacbookProgressApp: App {
    let container: ModelContainer
    @StateObject private var store: AppStore

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: GoalEntity.self, DepositEntity.self)
        } catch {
            // awaryjnie: pamięć tymczasowa, żeby aplikacja się uruchomiła
            container = try! ModelContainer(for: GoalEntity.self, DepositEntity.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        self.container = container
        _store = StateObject(wrappedValue: AppStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .modelContainer(container)
    }
}
