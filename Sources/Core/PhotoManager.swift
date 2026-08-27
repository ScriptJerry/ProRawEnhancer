import Foundation
import UIKit
import Photos

public final class PhotoManager: ObservableObject {
    public static let shared = PhotoManager()
    
    @Published public var isSaving: Bool = false
    @Published public var saveSuccess: Bool = false
    @Published public var errorMessage: String? = nil
    
    private init() {}
    
    /// Salva a imagem processada diretamente no rolo da câmera com máxima fidelidade
    public func saveToPhotoLibrary(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "PhotoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permissão de acesso à galeria negada."]))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
}
