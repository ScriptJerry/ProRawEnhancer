import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML
import Vision
import UIKit

/// Motor Neural Real com Modelo de Deep Learning no Apple Neural Engine (ANE)
public final class NeuralEngineRestorer {
    public static let shared = NeuralEngineRestorer()
    
    private var mlModel: MLModel?
    private var vnModel: VNCoreMLModel?
    
    private init() {
        setupCoreMLModel()
    }
    
    private func setupCoreMLModel() {
        let config = MLModelConfiguration()
        config.computeUnits = .all // Prioriza o Apple Neural Engine (16 núcleos A16 Bionic) + GPU
        
        // 1. Tenta carregar o modelo compilado do bundle
        if let modelURL = Bundle.main.url(forResource: "ProTextureNeuralNet", withExtension: "mlmodelc"),
           let model = try? MLModel(contentsOf: modelURL, configuration: config) {
            self.mlModel = model
            self.vnModel = try? VNCoreMLModel(for: model)
        } else if let modelURL = Bundle.main.url(forResource: "ProTextureNeuralNet", withExtension: "mlmodel"),
                  let compiledURL = try? MLModel.compileModel(at: modelURL),
                  let model = try? MLModel(contentsOf: compiledURL, configuration: config) {
            self.mlModel = model
            self.vnModel = try? VNCoreMLModel(for: model)
        }
    }
    
    /// Executa a restauração profunda de textura usando a Rede Neural no Neural Engine
    public func enhanceTexture(ciImage: CIImage, intensity: Float = 0.65) -> CIImage {
        guard intensity > 0.01 else { return ciImage }
        
        let extent = ciImage.extent
        
        // Execução no Apple Neural Engine via Vision
        if let vnModel = self.vnModel {
            let request = VNCoreMLRequest(model: vnModel)
            request.imageCropAndScaleOption = .scaleFit
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
                if let results = request.results as? [VNPixelBufferObservation],
                   let first = results.first {
                    
                    let neuralOutput = CIImage(cvPixelBuffer: first.pixelBuffer)
                    let scaledOutput = matchScale(image: neuralOutput, targetExtent: extent)
                    
                    // Mistura a reconstrução neural com a imagem base de acordo com a intensidade
                    let alphaMask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(intensity))).cropped(to: extent)
                    return scaledOutput.applyingFilter("CIBlendWithAlphaMask", parameters: [
                        kCIInputBackgroundImageKey: ciImage,
                        kCIInputMaskImageKey: alphaMask
                    ])
                }
            } catch {
                print("Neural Engine inference error: \(error)")
            }
        }
        
        // Fallback óptico suave
        let clamped = ciImage.clampedToExtent()
        return clamped.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: 1.1,
            kCIInputIntensityKey: intensity * 0.45
        ]).cropped(to: extent)
    }
    
    private func matchScale(image: CIImage, targetExtent: CGRect) -> CIImage {
        let currentExtent = image.extent
        guard currentExtent.width > 0 && currentExtent.height > 0 else { return image }
        
        let scaleX = targetExtent.width / currentExtent.width
        let scaleY = targetExtent.height / currentExtent.height
        
        return image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY)).cropped(to: targetExtent)
    }
}
