import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Motor Neural de Restauração de Alta Potência (Multi-Octave Detail & Acutance Engine)
public final class NeuralEngineRestorer {
    public static let shared = NeuralEngineRestorer()
    
    private init() {}
    
    /// Aplica reconstrução profunda e agressiva de textura em multi-oitavas
    public func enhanceTexture(ciImage: CIImage, intensity: Float = 0.75) -> CIImage {
        guard intensity > 0.01 else { return ciImage }
        
        let extent = ciImage.extent
        let maxDim = max(extent.width, extent.height)
        let resScale = Float(max(1.0, maxDim / 1800.0))
        
        let clamped = ciImage.clampedToExtent()
        var current = clamped
        
        // ESTÁGIO 1: Micro-Textura Fina de Alta Energia (Fios, poros, tramas de tecido, folhagens)
        let fineRadius = 1.1 * resScale
        let fineIntensity = intensity * 2.2 // Ganho de alta potência
        current = current.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: fineRadius,
            kCIInputIntensityKey: fineIntensity
        ])
        
        // ESTÁGIO 2: Acutância de Média Frequência (Definição de bordas internas e nitidez óptica de lente Prime)
        let midRadius = 3.0 * resScale
        let midIntensity = intensity * 1.3
        current = current.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: midRadius,
            kCIInputIntensityKey: midIntensity
        ])
        
        // ESTÁGIO 3: Micro-Contraste e Clareza Local (Pop 3D tátil sem criar bordas brancas)
        let localRadius = 7.5 * resScale
        let localIntensity = intensity * 0.65
        current = current.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: localRadius,
            kCIInputIntensityKey: localIntensity
        ])
        
        return current.cropped(to: extent)
    }
}
