import Foundation
import UIKit
import Photos

public final class PhotoManager: NSObject, ObservableObject {
    public static let shared = PhotoManager()
    
    private var saveCompletion: ((Bool, Error?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    /// Salva a imagem diretamente no rolo da câmera com confirmação garantida
    public func saveToPhotoLibrary(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        self.saveCompletion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async {
            if let error = error {
                self.saveCompletion?(false, error)
            } else {
                self.saveCompletion?(true, nil)
            }
            self.saveCompletion = nil
        }
    }
}
