import SwiftUI
import SwiftData

/// Métadonnées d'un document fraîchement capturé : titre, type, dates.
struct DocumentFormSheet: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var dismiss

    let brouillon: CoffreView.BrouillonDocument

    @State private var titre = ""
    @State private var type: TypeDocument = .ordonnance
    @State private var date = Date.now
    @State private var validiteActive = false
    @State private var dateValidite = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    TextField("Titre (ex. Ordonnance Dr Martin)", text: $titre)
                    Picker("Type", selection: $type) {
                        ForEach(TypeDocument.allCases) { t in
                            Text(t.libelle).tag(t)
                        }
                    }
                    DatePicker("Date du document", selection: $date, displayedComponents: .date)
                }
                if type == .ordonnance {
                    Section("Validité (optionnel)") {
                        Toggle("Date de fin de validité", isOn: $validiteActive)
                        if validiteActive {
                            DatePicker("Valable jusqu'au", selection: $dateValidite, displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle("Ranger au coffre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer() }
                        .disabled(titre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func enregistrer() {
        do {
            let nomFichier = try VaultFileStore().enregistrer(brouillon.data, extension: brouillon.ext)
            let document = DocumentItem(
                type: type,
                titre: titre.trimmingCharacters(in: .whitespaces),
                date: date,
                dateValidite: validiteActive ? dateValidite : nil,
                nomFichier: nomFichier,
                mimeType: brouillon.mimeType
            )
            contexte.insert(document)
            try contexte.save()
            dismiss()
        } catch {
            // Écriture locale : échec improbable, on garde la feuille ouverte.
        }
    }
}
