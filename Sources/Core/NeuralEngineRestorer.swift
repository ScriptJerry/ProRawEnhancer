import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import UIKit

/// Módulo de Restauração de Textura e Detalhes Neurais acelerado por Hardware
public final class NeuralEngineRestorer {
    public static let shared = NeuralEngineRestorer()
    
    private init() {}
    
    /// Aplica o pipeline neural de separação de frequências e reconstrução de textura
    public func enhanceTexture(ciImage: CIImage, intensity: Float = 0.7) -> CIImage {
        // 1. Filtro Bilateral de Preservação de Bordas (Isola a estrutura e suaviza ruído)
        let edgePreservingBase = ciImage.applyingFilter("CIBilateralFilter", parameters: [
            kCIInputRadiusKey: 2.5,
            "inputDistanceSigma": 0.14
        ])
        
        // 2. Extração da camada de alta frequência (Micro-Textura pura)
        let microTexture = ciImage.applyingFilter("CISubtractBlendMode", parameters: [
            kCIInputBackgroundImageKey: edgePreservingBase
        ])
        
        // 3. Realce adaptativo de textura
        let textureBoost = 1.0 + (intensity * 0.55)
        let boostedTexture = microTexture.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: textureBoost,
            kCIInputSaturationKey: 1.0,
            kCIInputBrightnessKey: 0.0
        ])
        
        // 4. Recombinação aditiva com a estrutura base
        let reconstructed = boostedTexture.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: edgePreservingBase
        ])
        
        // 5. Unsharp Masking de acutância óptica fina
        let finalSharpness = reconstructed.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: 0.9,
            kCIInputIntensityKey: intensity * 0.6
        ])
        
        return finalSharpness
    }
}
