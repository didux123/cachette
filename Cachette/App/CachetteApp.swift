import SwiftUI
import SwiftData

@main
struct CachetteApp: App {
    private let container: ModelContainer

    init() {
        container = ModelContainerFactory.production()
        do {
            try SeedService.seedSiNecessaire(contexte: container.mainContext)
        } catch {
            assertionFailure("Échec du seed des lieux par défaut : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(container)
    }
}
