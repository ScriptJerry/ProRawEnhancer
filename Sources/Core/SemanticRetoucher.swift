import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

public struct SemanticMattes {
    public var skin: CIImage?
    public var hair: CIImage?
    public var sky: CIImage?
    public var teeth: CIImage?
    
    public var hasAnyMatte: Bool {
        return skin != nil || hair != nil || sky != nil || teeth != nil
    }
}

/// Módulo de Edição Semântica Seletiva baseada em IA (aproveita as máscaras do Apple ProRAW)
public final class SemanticRetoucher {
    public static let shared = SemanticRetoucher()
    
    private init() {}
    
    /// Extrai os mapas semânticos embutidos no CIRAWFilter
    public func extractMattes(from rawFilter: CIRAWFilter) -> SemanticMattes {
        var mattes = SemanticMattes()
        mattes.skin = rawFilter.semanticSegmentationSkinMatte
        mattes.hair = rawFilter.semanticSegmentationHairMatte
        mattes.sky = rawFilter.semanticSegmentationSkyMatte
        mattes.teeth = rawFilter.semanticSegmentationTeethMatte
        return mattes
    }
    
    /// Aplica tratamento fotográfico cirúrgico em cada região semântica isolada
    public func applySelectiveRetouch(to inputImage: CIImage, mattes: SemanticMattes, settings: EnhancementSettings) -> CIImage {
        guard settings.enableSemanticRetouch && mattes.hasAnyMatte else {
            return inputImage
        }
        
        var currentImage = inputImage
        let targetExtent = inputImage.extent
        
        // 1. PROCESSAMENTO DE CABELO & BARBA (Acutância Máxima Fio a Fio)
        if let hairMask = mattes.hair, settings.hairDetailBoost > 0.01 {
            let scaledMask = matchMaskScale(mask: hairMask, targetExtent: targetExtent)
            
            // Nitidez ultra-fina focada exclusivamente nas fibras capilares
            let hairEnhanced = currentImage.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.2,
                kCIInputIntensityKey: settings.hairDetailBoost * 2.2
            ])
            
            currentImage = hairEnhanced.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 2. PROCESSAMENTO DE PELE (Preservação de Textura Natural & Suavização Orgânica)
        if let skinMask = mattes.skin, settings.skinSmoothing > 0.01 {
            let scaledMask = matchMaskScale(mask: skinMask, targetExtent: targetExtent)
            
            // Suavização bilateral que remove manchas sem apagar poros reais
            let smoothedSkin = currentImage.applyingFilter("CIBilateralFilter", parameters: [
                kCIInputRadiusKey: 2.0 + (settings.skinSmoothing * 3.0),
                "inputDistanceSigma": 0.10
            ])
            
            // Leve aquecimento saudável no tom de pele
            let warmSkin = smoothedSkin.applyingFilter("CIVibrance", parameters: [
                "inputAmount": 0.08
            ])
            
            currentImage = warmSkin.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 3. PROCESSAMENTO DE CÉU (Gradiente Analógico e Supressão de Ruído Azul)
        if let skyMask = mattes.sky, settings.skyEnhancement > 0.01 {
            let scaledMask = matchMaskScale(mask: skyMask, targetExtent: targetExtent)
            
            // Curva de contraste e saturação profunda no céu sem estourar as nuvens
            let deepSky = currentImage.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.0 + (settings.skyEnhancement * 0.15),
                kCIInputSaturationKey: 1.0 + (settings.skyEnhancement * 0.25)
            ])
            
            currentImage = deepSky.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        return currentImage
    }
    
    // Ajusta a escala da máscara para coincidir exatamente com a imagem alvo
    private func matchMaskScale(mask: CIImage, targetExtent: CGRect) -> CIImage {
        let maskExtent = mask.extent
        guard maskExtent.width > 0 && maskExtent.height > 0 else { return mask }
        
        let scaleX = targetExtent.width / maskExtent.width
        let scaleY = targetExtent.height / maskExtent.height
        
        return mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY)).cropped(to: targetExtent)
    }
}
