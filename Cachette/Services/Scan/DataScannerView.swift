import SwiftUI
import VisionKit

/// Wrapper SwiftUI du scanner live VisionKit, restreint aux codes des boîtes
/// de médicaments (Datamatrix GS1, EAN-13, Code 128).
/// L'abstraction isole ce choix : bascule possible vers AVCaptureSession +
/// VNDetectBarcodesRequest sans toucher au reste du flux.
struct DataScannerView: UIViewControllerRepresentable {
    /// Payload brut du code détecté.
    let onScan: (String) -> Void
    /// Scan en pause (feuille de confirmation ouverte) ?
    var enPause = false

    static var estSupporte: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.dataMatrix, .ean13, .code128])
            ],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        if enPause {
            scanner.stopScanning()
        } else {
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        private var dernierPayload: String?

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue,
                   payload != dernierPayload {
                    dernierPayload = payload
                    onScan(payload)
                    break
                }
            }
        }
    }
}
