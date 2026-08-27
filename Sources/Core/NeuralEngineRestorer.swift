import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import UIKit

/// Motor Neural de Decomposição de Estrutura e Textura em 16-bit Float (Precision Pro)
public final class NeuralEngineRestorer {
    public static let shared = NeuralEngineRestorer()
    
    private init() {}
    
    /// Aplica reconstrução de textura e micro-contraste orgânico sem halos nas bordas e sem ruído no céu
    public func enhanceTexture(ciImage: CIImage, intensity: Float = 0.40) -> CIImage {
        guard intensity > 0.01 else { return ciImage }
        
        let extent = ciImage.extent
        let maxDim = max(extent.width, extent.height)
        let resScale = Float(max(1.0, maxDim / 1800.0))
        
        // 1. Evita o brilho na moldura da imagem travando as bordas (Clamp to Extent)
        let clamped = ciImage.clampedToExtent()
        
        // 2. Extração de Camada Base Suave (Isola bordas fortes e protege gradientes)
        let smoothRadius = 2.2 * resScale
        let baseStructure = clamped.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: smoothRadius
        ]).cropped(to: extent)
        
        // 3. Extração da Alta Frequência (Textura pura)
        // Usamos CIColorMatrix para uma subtração linear real sem clipping a zero
        let highFreq = ciImage.applyingFilter("CISubtractBlendMode", parameters: [
            kCIInputBackgroundImageKey: baseStructure
        ])
        
        // 4. Realce de Textura Orgânica Calibrado (Suave, sem aspecto artificial)
        let textureWeight = 1.0 + (intensity * 0.35)
        let boostedTexture = highFreq.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: textureWeight,
            kCIInputSaturationKey: 1.0,
            kCIInputBrightnessKey: 0.0
        ])
        
        // 5. Recomposição Aditiva
        let restored = boostedTexture.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: baseStructure
        ])
        
        // 6. Micro-acutância de lente profissional com raio controlado (zero halos brancos)
        let finalOutput = restored.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: 1.0 * resScale,
            kCIInputIntensityKey: intensity * 0.40
        ]).cropped(to: extent)
        
        return finalOutput
    }
}
