import Foundation
import UIKit
import Photos

public final class PhotoManager: NSObject, ObservableObject {
    public static let shared = PhotoManager()
    
    private override init() {
        super.init()
    }
    
    /// Salva a imagem processada como JPEG no rolo da câmera (modo rápido / preview)
    public func saveToPhotoLibrary(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                let err = NSError(domain: "PhotoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permissão de galeria negada."])
                DispatchQueue.main.async { completion(false, err) }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = "public.jpeg"
                if let jpegData = image.jpegData(compressionQuality: 0.96) {
                    request.addResource(with: .photo, data: jpegData, options: options)
                }
            }) { success, error in
                DispatchQueue.main.async { completion(success, error) }
            }
        }
    }
    
    /// Salva como HEIF com o Gain Map HDR embutido preservando a aparência HDR do ProRAW (iOS 17+)
    public func saveHEIFWithGainMap(heifData: Data, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                let err = NSError(domain: "PhotoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permissão de galeria negada."])
                DispatchQueue.main.async { completion(false, err) }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                // UTI HEIF com suporte a Gain Map HDR (HEIC)
                options.uniformTypeIdentifier = "public.heic"
                request.addResource(with: .photo, data: heifData, options: options)
            }) { success, error in
                DispatchQueue.main.async { completion(success, error) }
            }
        }
    }
}
