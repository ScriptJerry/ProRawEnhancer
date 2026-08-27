import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

public struct SemanticMattes {
    public var skin: CIImage?
    public var hair: CIImage?
    public var sky: CIImage?
    public var teeth: CIImage?
    public var glasses: CIImage?
    public var depth: CIImage?
    
    public init(
        skin: CIImage? = nil,
        hair: CIImage? = nil,
        sky: CIImage? = nil,
        teeth: CIImage? = nil,
        glasses: CIImage? = nil,
        depth: CIImage? = nil
    ) {
        self.skin = skin
        self.hair = hair
        self.sky = sky
        self.teeth = teeth
        self.glasses = glasses
        self.depth = depth
    }
    
    public var hasAnyMatte: Bool {
        return skin != nil || hair != nil || sky != nil || teeth != nil || glasses != nil || depth != nil
    }
}

/// Módulo de Edição Semântica Profissional (Retoque Cirúrgico em 6 Canais de IA)
public final class SemanticRetoucher {
    public static let shared = SemanticRetoucher()
    
    private init() {}
    
    /// Extrai todos os mapas semânticos embutidos no CIRAWFilter
    public func extractMattes(from rawFilter: CIRAWFilter) -> SemanticMattes {
        return SemanticMattes(
            skin: rawFilter.semanticSegmentationSkinMatte,
            hair: rawFilter.semanticSegmentationHairMatte,
            sky: rawFilter.semanticSegmentationSkyMatte,
            teeth: rawFilter.semanticSegmentationTeethMatte,
            glasses: rawFilter.semanticSegmentationGlassesMatte,
            depth: rawFilter.portraitEffectsMatte
        )
    }
    
    /// Aplica tratamento fotográfico cirúrgico em cada canal semântico isolado
    public func applySelectiveRetouch(to inputImage: CIImage, mattes: SemanticMattes, settings: EnhancementSettings) -> CIImage {
        guard settings.enableSemanticRetouch && mattes.hasAnyMatte else {
            return inputImage
        }
        
        var currentImage = inputImage
        let targetExtent = inputImage.extent
        let maxDim = max(targetExtent.width, targetExtent.height)
        let resScale = Float(max(1.0, maxDim / 1200.0))
        
        // 1. CABELO & BARBA (Acutância e Nitidez Fio a Fio)
        if let hairMask = mattes.hair, settings.hairDetailBoost > 0.01 {
            let scaledMask = matchMaskScale(mask: hairMask, targetExtent: targetExtent)
            let hairEnhanced = currentImage.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.2 * resScale,
                kCIInputIntensityKey: settings.hairDetailBoost * 2.2
            ])
            currentImage = hairEnhanced.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 2. PELE HUMANA (Retoque Orgânico: Preserva Poros e Remove Manchas)
        if let skinMask = mattes.skin, settings.skinSmoothing > 0.01 {
            let scaledMask = matchMaskScale(mask: skinMask, targetExtent: targetExtent)
            let smoothedSkin = currentImage.applyingFilter("CIBilateralFilter", parameters: [
                kCIInputRadiusKey: (2.0 + (settings.skinSmoothing * 3.0)) * resScale,
                "inputDistanceSigma": 0.10
            ])
            let warmSkin = smoothedSkin.applyingFilter("CIVibrance", parameters: [
                "inputAmount": 0.08
            ])
            currentImage = warmSkin.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 3. CÉU & NUVENS (Efeito Polarizador Cinematográfico)
        if let skyMask = mattes.sky, settings.skyEnhancement > 0.01 {
            let scaledMask = matchMaskScale(mask: skyMask, targetExtent: targetExtent)
            let deepSky = currentImage.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.0 + (settings.skyEnhancement * 0.15),
                kCIInputSaturationKey: 1.0 + (settings.skyEnhancement * 0.25)
            ])
            currentImage = deepSky.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 4. DENTES & SORRISO (Clareamento Natural de Estúdio)
        if let teethMask = mattes.teeth, settings.teethBrightening > 0.01 {
            let scaledMask = matchMaskScale(mask: teethMask, targetExtent: targetExtent)
            // Aumenta levemente o brilho e reduz a saturação para neutralizar tons amarelados
            let whitenedTeeth = currentImage.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: settings.teethBrightening * 0.12,
                kCIInputSaturationKey: 1.0 - (settings.teethBrightening * 0.40),
                kCIInputContrastKey: 1.05
            ])
            currentImage = whitenedTeeth.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 5. ÓCULOS & ARMAÇÕES (Anti-Reflexo e Nitidez de Lentes)
        if let glassesMask = mattes.glasses, settings.glassesClarity > 0.01 {
            let scaledMask = matchMaskScale(mask: glassesMask, targetExtent: targetExtent)
            let sharpGlasses = currentImage.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.5 * resScale,
                kCIInputIntensityKey: settings.glassesClarity * 1.5
            ]).applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.0 + (settings.glassesClarity * 0.10)
            ])
            currentImage = sharpGlasses.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 6. PROFUNDIDADE / BOKEH ÓPTICO (Simulação de Queda de Foco de Lente Full Frame)
        if let depthMask = mattes.depth, settings.opticalBokehDepth > 0.01 {
            let scaledMask = matchMaskScale(mask: depthMask, targetExtent: targetExtent)
            
            // Inverte a máscara do sujeito para atuar no fundo (background)
            let backgroundMask = scaledMask.applyingFilter("CIColorInvert")
            
            // Aplica um desfoque suave de bokeh no fundo
            let blurredBackground = currentImage.applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: settings.opticalBokehDepth * 6.0 * resScale
            ])
            
            currentImage = blurredBackground.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: backgroundMask
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
