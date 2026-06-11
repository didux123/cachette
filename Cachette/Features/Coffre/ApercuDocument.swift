import SwiftUI
import QuickLook

/// Visionneuse de document du coffre (image ou PDF) via QuickLook.
struct ApercuDocument: View {
    @Environment(\.dismiss) private var dismiss
    let document: DocumentItem

    var body: some View {
        NavigationStack {
            QuickLookView(url: VaultFileStore().url(pour: document.nomFichier))
                .navigationTitle(document.titre)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") { dismiss() }
                    }
                }
        }
    }
}

private struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controleur = QLPreviewController()
        controleur.dataSource = context.coordinator
        return controleur
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
