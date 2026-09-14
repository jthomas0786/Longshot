import SwiftUI
import PhotosUI
import Photos

@MainActor
final class StitchViewModel: ObservableObject {
    @Published var pickerItems: [PhotosPickerItem] = []
    @Published var sourceImages: [UIImage] = []
    @Published var stitchedImage: UIImage?
    @Published var isWorking = false
    @Published var progressText = ""
    @Published var errorMessage: String?
    @Published var saveMessage: String?

    func loadSelectedImages() async {
        guard !pickerItems.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        saveMessage = nil
        progressText = "Loading screenshots…"

        var loaded: [UIImage] = []
        for (index, item) in pickerItems.enumerated() {
            progressText = "Loading screenshot \(index + 1) of \(pickerItems.count)…"
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image.fixedOrientation())
                }
            } catch {
                errorMessage = "Couldn’t load one of the selected screenshots."
            }
        }
        sourceImages = loaded
        isWorking = false
        progressText = ""
    }

    func stitch() async {
        guard sourceImages.count >= 2 else {
            errorMessage = "Choose at least two screenshots."
            return
        }
        isWorking = true
        errorMessage = nil
        saveMessage = nil
        progressText = "Finding overlaps…"

        let images = sourceImages
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try ScreenshotStitcher().stitch(images: images)
            }.value
            stitchedImage = result
            progressText = "Done"
        } catch {
            errorMessage = error.localizedDescription
            progressText = ""
        }
        isWorking = false
    }

    func reset() {
        pickerItems = []
        sourceImages = []
        stitchedImage = nil
        errorMessage = nil
        saveMessage = nil
        progressText = ""
    }

    func saveToPhotos() {
        guard let stitchedImage else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    self.errorMessage = "Photo access is needed to save the finished image."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: stitchedImage)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        self.saveMessage = "Saved to Photos."
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Couldn’t save the image."
                    }
                }
            }
        }
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
