import Foundation
import SwiftData
import Testing
@testable import Cachette

struct SeedServiceTests {
    @Test func leSeedCreeLesDeuxLieuxParDefaut() throws {
        let container = ModelContainerFactory.inMemory()
        let contexte = container.mainContext

        try SeedService.seedSiNecessaire(contexte: contexte)

        let lieux = try contexte.fetch(FetchDescriptor<Lieu>(sortBy: [SortDescriptor(\.ordre)]))
        #expect(lieux.count == 2)
        #expect(lieux.map(\.nom) == ["Chez moi", "Sur moi"])
        #expect(lieux.filter(\.estSurMoi).count == 1)
    }

    @Test func leSeedEstIdempotent() throws {
        let container = ModelContainerFactory.inMemory()
        let contexte = container.mainContext

        try SeedService.seedSiNecessaire(contexte: contexte)
        try SeedService.seedSiNecessaire(contexte: contexte)
        try SeedService.seedSiNecessaire(contexte: contexte)

        let total = try contexte.fetchCount(FetchDescriptor<Lieu>())
        #expect(total == 2)
    }
}

struct StockServiceLieuxTests {
    @Test func supprimerUnLieuNormalFonctionne() throws {
        let container = ModelContainerFactory.inMemory()
        let contexte = container.mainContext
        let service = StockService(contexte: contexte)

        let lieu = try service.creerLieu(nom: "Chez mes parents", type: .parents)
        try service.supprimerLieu(lieu)

        let restants = try contexte.fetchCount(FetchDescriptor<Lieu>())
        #expect(restants == 0)
    }

    @Test func supprimerSurMoiEstRefuse() throws {
        let container = ModelContainerFactory.inMemory()
        let contexte = container.mainContext
        try SeedService.seedSiNecessaire(contexte: contexte)
        let service = StockService(contexte: contexte)

        let surMoi = try #require(
            try contexte.fetch(FetchDescriptor<Lieu>(predicate: #Predicate { $0.estSurMoi })).first
        )

        #expect(throws: StockServiceError.lieuSurMoiNonSupprimable) {
            try service.supprimerLieu(surMoi)
        }
        let total = try contexte.fetchCount(FetchDescriptor<Lieu>())
        #expect(total == 2)
    }

    @Test func creerLieuIncrementeLOrdre() throws {
        let container = ModelContainerFactory.inMemory()
        let contexte = container.mainContext
        try SeedService.seedSiNecessaire(contexte: contexte)
        let service = StockService(contexte: contexte)

        let nouveau = try service.creerLieu(nom: "Travail", type: .travail)
        #expect(nouveau.ordre == 2)
    }
}
