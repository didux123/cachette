import SwiftUI
import SwiftData
import BackgroundTasks
import TipKit

@main
struct CachetteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        container = ModelContainerFactory.production()
        do {
            try SeedService.seedSiNecessaire(contexte: container.mainContext)
        } catch {
            assertionFailure("Échec du seed des lieux par défaut : \(error)")
        }
        Self.enregistrerTacheBDPM()
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .task {
                    // Filet de sécurité : les BGTask ne sont jamais garanties.
                    _ = await BDPMRefreshService()
                        .rafraichirSiPlusVieuxQue(BDPMRefreshService.seuilOpportunisteJours)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Self.programmerTacheBDPMSiNecessaire()
            }
        }
    }

    // MARK: - Tâche de fond BDPM (refresh ~mensuel)

    private static func enregistrerTacheBDPM() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BDPMRefreshService.identifiantTache,
            using: nil
        ) { tache in
            let operation = Task {
                let reussi = await BDPMRefreshService()
                    .rafraichirSiPlusVieuxQue(BDPMRefreshService.seuilProgrammationJours)
                tache.setTaskCompleted(success: reussi)
            }
            tache.expirationHandler = {
                operation.cancel()
                tache.setTaskCompleted(success: false)
            }
        }
    }

    private static func programmerTacheBDPMSiNecessaire() {
        let service = BDPMRefreshService()
        guard let age = service.ageSnapshotJours(),
              age > BDPMRefreshService.seuilProgrammationJours
        else { return }

        let requete = BGProcessingTaskRequest(identifier: BDPMRefreshService.identifiantTache)
        requete.requiresNetworkConnectivity = true
        requete.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(requete)
    }
}
