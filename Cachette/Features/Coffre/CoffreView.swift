import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// Coffre à documents (P0-7) : ordonnances et comptes-rendus, stockés
/// chiffrés en local, consultables hors-ligne, protégés par Face ID.
struct CoffreView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DocumentItem.date, order: .reverse) private var documents: [DocumentItem]

    @AppStorage("coffreVerrouActive") private var verrouActive = true
    @State private var verrou = VaultLockService()

    @State private var recherche = ""
    @State private var photoChoisie: PhotosPickerItem?
    @State private var cameraPresentee = false
    @State private var importPDFPresente = false
    @State private var brouillon: BrouillonDocument?
    @State private var documentAOuvrir: DocumentItem?

    /// Document fraîchement capturé, en attente de titre/type.
    struct BrouillonDocument: Identifiable {
        let id = UUID()
        let data: Data
        let ext: String
        let mimeType: String
    }

    private var documentsFiltres: [DocumentItem] {
        guard !recherche.isEmpty else { return documents }
        let terme = recherche.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return documents.filter {
            $0.titre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(terme)
                || $0.type.libelle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(terme)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if verrouActive && verrou.estVerrouille {
                    ecranVerrouille
                } else {
                    contenu
                }
            }
            .navigationTitle("Coffre")
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    verrou.verrouiller()
                }
            }
        }
    }

    // MARK: - Verrou

    private var ecranVerrouille: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🔒").font(.system(size: 56))
            Text("Tes documents de santé sont protégés.")
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
            Button {
                Task { await verrou.deverrouiller() }
            } label: {
                Label("Déverrouiller", systemImage: "faceid")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(CachetteColors.rouxCachette)
            Spacer()
            Spacer()
        }
        .task {
            // Tentative directe à l'arrivée sur l'onglet : un seul geste.
            await verrou.deverrouiller()
        }
    }

    // MARK: - Contenu

    private var contenu: some View {
        Group {
            if documents.isEmpty {
                emptyState
            } else {
                listeDocuments
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            cameraPresentee = true
                        } label: {
                            Label("Photographier", systemImage: "camera")
                        }
                    }
                    PhotosPicker(selection: $photoChoisie, matching: .images) {
                        Label("Depuis la photothèque", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        importPDFPresente = true
                    } label: {
                        Label("Importer un PDF", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
            }
        }
        .searchable(text: $recherche, prompt: "Titre ou type…")
        .onChange(of: photoChoisie) { _, nouveau in
            guard let nouveau else { return }
            Task {
                if let data = try? await nouveau.loadTransferable(type: Data.self) {
                    brouillon = BrouillonDocument(data: data, ext: "jpg", mimeType: "image/jpeg")
                }
                photoChoisie = nil
            }
        }
        .fullScreenCover(isPresented: $cameraPresentee) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    brouillon = BrouillonDocument(data: data, ext: "jpg", mimeType: "image/jpeg")
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $importPDFPresente, allowedContentTypes: [.pdf]) { resultat in
            if case .success(let url) = resultat {
                let acces = url.startAccessingSecurityScopedResource()
                defer { if acces { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    brouillon = BrouillonDocument(data: data, ext: "pdf", mimeType: "application/pdf")
                }
            }
        }
        .sheet(item: $brouillon) { brouillon in
            DocumentFormSheet(brouillon: brouillon)
        }
        .sheet(item: $documentAOuvrir) { document in
            ApercuDocument(document: document)
        }
    }

    private var listeDocuments: some View {
        List {
            ForEach(documentsFiltres) { document in
                Button {
                    documentAOuvrir = document
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: document.mimeType == "application/pdf" ? "doc.richtext" : "photo")
                            .font(.title3)
                            .foregroundStyle(CachetteColors.rouxCachette)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.titre)
                                .font(CachetteTypography.corps.weight(.medium))
                            Text("\(document.type.libelle) · \(document.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(CachetteTypography.legende)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        supprimer(document)
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🐿️").font(.system(size: 64))
            Text("Tes ordonnances, toujours sur toi.\nAjoute la première — photo ou PDF.")
                .font(CachetteTypography.corps)
                .foregroundStyle(CachetteColors.brunNoisette)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func supprimer(_ document: DocumentItem) {
        VaultFileStore().supprimer(nomFichier: document.nomFichier)
        contexte.delete(document)
        try? contexte.save()
    }
}
