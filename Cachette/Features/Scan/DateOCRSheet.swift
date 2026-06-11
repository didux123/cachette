import SwiftUI
import PhotosUI

/// Lecture d'une date de péremption par photo (P0-5) :
/// capture/choix d'image → OCR Vision local → dates candidates → validation
/// explicite par l'utilisateur avant rattachement.
struct DateOCRSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Date validée par l'utilisateur.
    let onDateValidee: (Date) -> Void

    @State private var photoChoisie: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var cameraPresentee = false
    @State private var analyseEnCours = false
    @State private var candidates: [Date] = []
    @State private var aucuneDateTrouvee = false

    private let ocr: any OCRProvider = VisionOCRProvider()

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo de la date") {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            cameraPresentee = true
                        } label: {
                            Label("Prendre une photo", systemImage: "camera")
                        }
                    }
                    PhotosPicker(selection: $photoChoisie, matching: .images) {
                        Label("Choisir dans la photothèque", systemImage: "photo.on.rectangle")
                    }
                }

                if analyseEnCours {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Lecture en cours…").padding(.leading, 8)
                        }
                    }
                }

                if !candidates.isEmpty {
                    Section("Dates trouvées — choisis la bonne") {
                        ForEach(candidates, id: \.self) { date in
                            Button {
                                onDateValidee(date)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(date, format: .dateTime.day().month(.wide).year())
                                        .font(CachetteTypography.corps.weight(.medium))
                                    Spacer()
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(CachetteColors.vertSauge)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                if aucuneDateTrouvee {
                    Section {
                        Label {
                            Text("Aucune date lisible sur cette photo. Réessaie en cadrant la date de plus près, ou saisis-la à la main.")
                        } icon: {
                            Text("🤔")
                        }
                        .font(CachetteTypography.corps)
                    }
                }
            }
            .navigationTitle("Lire la péremption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onChange(of: photoChoisie) { _, nouveau in
                guard let nouveau else { return }
                Task {
                    if let data = try? await nouveau.loadTransferable(type: Data.self),
                       let chargee = UIImage(data: data) {
                        image = chargee
                        await analyser(chargee)
                    }
                }
            }
            .fullScreenCover(isPresented: $cameraPresentee) {
                CameraPicker { capturee in
                    image = capturee
                    Task { await analyser(capturee) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func analyser(_ image: UIImage) async {
        guard let cgImage = image.cgImage else { return }
        analyseEnCours = true
        aucuneDateTrouvee = false
        candidates = []
        defer { analyseEnCours = false }

        let lignes = (try? await ocr.lignesDeTexte(dans: cgImage)) ?? []
        candidates = Array(ExpiryDateParser.meilleuresDates(dans: lignes).prefix(4))
        aucuneDateTrouvee = candidates.isEmpty
    }
}

/// Capture caméra minimaliste (UIImagePickerController).
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
