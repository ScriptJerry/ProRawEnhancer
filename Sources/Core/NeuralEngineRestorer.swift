import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Motor de Restauração Neural Multi-Escala (Simula a acutância e separação de textura de sensores Full Frame)
public final class NeuralEngineRestorer {
    public static let shared = NeuralEngineRestorer()
    
    private init() {}
    
    /// Aplica a reconstrução neural com adaptação dinâmica para a resolução real da imagem (48MP vs Preview)
    public func enhanceTexture(ciImage: CIImage, intensity: Float = 0.75) -> CIImage {
        guard intensity > 0.01 else { return ciImage }
        
        let extent = ciImage.extent
        let maxDimension = max(extent.width, extent.height)
        
        // Fator de escala: Em 48MP (8000px), o raio do filtro precisa ser ~6.5x maior do que no preview (1200px)
        // para atingir as mesmas frequências espaciais do sensor
        let resScale = Float(max(1.0, maxDimension / 1200.0))
        
        var output = ciImage
        
        // BANDA 1: Micro-Textura Fina (Poros da pele, fios de cabelo, trama de tecido, folhagens)
        let fineRadius = 1.4 * resScale
        let fineIntensity = intensity * 1.6
        output = output.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: fineRadius,
            kCIInputIntensityKey: fineIntensity
        ])
        
        // BANDA 2: Acutância Óptica de Média Frequência (Sensação de profundidade 3D e nitidez de lente prime)
        let medRadius = 4.8 * resScale
        let medIntensity = intensity * 0.85
        output = output.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: medRadius,
            kCIInputIntensityKey: medIntensity
        ])
        
        // BANDA 3: Realce de Micro-Contraste Local (Clarity fotográfica sem criar halos brancos)
        let localRadius = 14.0 * resScale
        let localIntensity = intensity * 0.35
        output = output.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: localRadius,
            kCIInputIntensityKey: localIntensity
        ])
        
        return output
    }
}
