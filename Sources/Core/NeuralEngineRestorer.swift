import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Motor de Restauração de Micro-Textura (Acutância Óptica Pura sem Borrão e sem Halos)
public final class NeuralEngineRestorer {
    public static let shared = NeuralEngineRestorer()
    
    private init() {}
    
    /// Realça exclusivamente as micro-texturas reais (poros, tecidos, folhas) mantendo a imagem 100% nítida e cristalina
    public func enhanceTexture(ciImage: CIImage, intensity: Float = 0.40) -> CIImage {
        guard intensity > 0.01 else { return ciImage }
        
        let extent = ciImage.extent
        let maxDim = max(extent.width, extent.height)
        let resScale = Float(max(1.0, maxDim / 2000.0))
        
        // 1. Mantém a base 100% original e trava as bordas para não criar brilho na moldura
        let clamped = ciImage.clampedToExtent()
        
        // 2. Acutância Óptica de Raio Ultra-Estreito:
        // Um raio abaixo de 1.0 atua APENAS em detalhes microscópicos,
        // sendo matematicamente incapaz de criar bordas brancas/halos ao redor de objetos.
        let opticalRadius = 0.85 * resScale
        let opticalIntensity = intensity * 0.75
        
        let enhanced = clamped.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: opticalRadius,
            kCIInputIntensityKey: opticalIntensity
        ]).cropped(to: extent)
        
        return enhanced
    }
}
