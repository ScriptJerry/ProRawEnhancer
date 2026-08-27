import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML
import Vision
import UIKit

/// Motor Neural com Suporte a Dimensões Nativas Dinâmicas (Zero Distorção / Zero Letterbox)
public final class NeuralEngineRestorer {
    public static let shared = NeuralEngineRestorer()
    
    private var mlModel: MLModel?
    private var vnModel: VNCoreMLModel?
    
    private init() {
        setupCoreMLModel()
    }
    
    private func setupCoreMLModel() {
        let config = MLModelConfiguration()
        config.computeUnits = .all // Prioriza o Apple Neural Engine (ANE)
        
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
    
    /// PREVIEW AO VIVO (60 FPS): Resposta instantânea na tela
    public func quickPreviewAcutance(ciImage: CIImage, intensity: Float = 0.65) -> CIImage {
        guard intensity > 0.01 else { return ciImage }
        let clamped = ciImage.clampedToExtent()
        return clamped.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: 0.85,
            kCIInputIntensityKey: intensity * 0.45
        ]).cropped(to: ciImage.extent)
    }
    
    /// EXPORTAÇÃO FINAL (FORÇA TOTAL): Rede Neural Nativa no Apple Neural Engine
    public func enhanceTexture(ciImage: CIImage, intensity: Float = 0.75) -> CIImage {
        guard intensity > 0.01 else { return ciImage }
        
        let targetExtent = ciImage.extent
        
        // Execução no Neural Engine via Vision com proporção nativa exata
        if let vnModel = self.vnModel {
            let request = VNCoreMLRequest(model: vnModel)
            request.imageCropAndScaleOption = .scaleFill // Preenchimento 1:1 sem letterboxing/barras pretas
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
                if let results = request.results as? [VNPixelBufferObservation],
                   let first = results.first {
                    
                    let neuralOutput = CIImage(cvPixelBuffer: first.pixelBuffer)
                    let alignedOutput = matchExactExtent(image: neuralOutput, targetExtent: targetExtent)
                    
                    // Mistura perfeitamente alinhada
                    let alphaMask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(intensity))).cropped(to: targetExtent)
                    return alignedOutput.applyingFilter("CIBlendWithAlphaMask", parameters: [
                        kCIInputBackgroundImageKey: ciImage,
                        kCIInputMaskImageKey: alphaMask
                    ])
                }
            } catch {
                print("Neural Engine inference error: \(error)")
            }
        }
        
        // Fallback óptico suave alinhado
        let clamped = ciImage.clampedToExtent()
        return clamped.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: 1.1,
            kCIInputIntensityKey: intensity * 0.50
        ]).cropped(to: targetExtent)
    }
    
    private func matchExactExtent(image: CIImage, targetExtent: CGRect) -> CIImage {
        let currentExtent = image.extent
        guard currentExtent.width > 0 && currentExtent.height > 0 else { return image }
        
        let scaleX = targetExtent.width / currentExtent.width
        let scaleY = targetExtent.height / currentExtent.height
        
        return image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY)).cropped(to: targetExtent)
    }
}
