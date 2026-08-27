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
    
    /// Aplica tratamento fotográfico cirúrgico em cada canal semântico isolado com proteção de gradientes
    public func applySelectiveRetouch(to inputImage: CIImage, mattes: SemanticMattes, settings: EnhancementSettings) -> CIImage {
        guard settings.enableSemanticRetouch && mattes.hasAnyMatte else {
            return inputImage
        }
        
        var currentImage = inputImage
        let targetExtent = inputImage.extent
        let maxDim = max(targetExtent.width, targetExtent.height)
        let resScale = Float(max(1.0, maxDim / 1800.0))
        
        // 1. CABELO & BARBA (Acutância Equilibrada e Textura Fina)
        if let hairMask = mattes.hair, settings.hairDetailBoost > 0.01 {
            let scaledMask = matchMaskScale(mask: hairMask, targetExtent: targetExtent)
            let hairEnhanced = currentImage.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.0 * resScale,
                kCIInputIntensityKey: settings.hairDetailBoost * 0.65
            ]).cropped(to: targetExtent)
            
            currentImage = hairEnhanced.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 2. PELE HUMANA (Preservação de Poros e Remoção Suave de Manchas)
        if let skinMask = mattes.skin, settings.skinSmoothing > 0.01 {
            let scaledMask = matchMaskScale(mask: skinMask, targetExtent: targetExtent)
            let smoothedSkin = currentImage.clampedToExtent().applyingFilter("CIBilateralFilter", parameters: [
                kCIInputRadiusKey: (1.8 + (settings.skinSmoothing * 2.0)) * resScale,
                "inputDistanceSigma": 0.08
            ]).cropped(to: targetExtent)
            
            let warmSkin = smoothedSkin.applyingFilter("CIVibrance", parameters: [
                "inputAmount": 0.05
            ])
            
            currentImage = warmSkin.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 3. CÉU & NUVENS (Proteção de Gradiente 16-bit, Zero Banding)
        if let skyMask = mattes.sky, settings.skyEnhancement > 0.01 {
            let scaledMask = matchMaskScale(mask: skyMask, targetExtent: targetExtent)
            // Usa Vibrance em vez de ColorControls para não quebrar o bit-depth em faixas
            let enhancedSky = currentImage.applyingFilter("CIVibrance", parameters: [
                "inputAmount": settings.skyEnhancement * 0.25
            ])
            
            currentImage = enhancedSky.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 4. DENTES & SORRISO (Clareamento Natural)
        if let teethMask = mattes.teeth, settings.teethBrightening > 0.01 {
            let scaledMask = matchMaskScale(mask: teethMask, targetExtent: targetExtent)
            let whitenedTeeth = currentImage.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: settings.teethBrightening * 0.08,
                kCIInputSaturationKey: 1.0 - (settings.teethBrightening * 0.30)
            ])
            currentImage = whitenedTeeth.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 5. ÓCULOS & ARMAÇÕES (Claridade sem Reflexos Estranhos)
        if let glassesMask = mattes.glasses, settings.glassesClarity > 0.01 {
            let scaledMask = matchMaskScale(mask: glassesMask, targetExtent: targetExtent)
            let sharpGlasses = currentImage.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.2 * resScale,
                kCIInputIntensityKey: settings.glassesClarity * 0.50
            ]).cropped(to: targetExtent)
            
            currentImage = sharpGlasses.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: scaledMask
            ])
        }
        
        // 6. PROFUNDIDADE / BOKEH ÓPTICO (Desfoque Suave de Fundo)
        if let depthMask = mattes.depth, settings.opticalBokehDepth > 0.01 {
            let scaledMask = matchMaskScale(mask: depthMask, targetExtent: targetExtent)
            let backgroundMask = scaledMask.applyingFilter("CIColorInvert")
            
            let blurredBackground = currentImage.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: settings.opticalBokehDepth * 4.0 * resScale
            ]).cropped(to: targetExtent)
            
            currentImage = blurredBackground.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: backgroundMask
            ])
        }
        
        return currentImage
    }
    
    private func matchMaskScale(mask: CIImage, targetExtent: CGRect) -> CIImage {
        let maskExtent = mask.extent
        guard maskExtent.width > 0 && maskExtent.height > 0 else { return mask }
        
        let scaleX = targetExtent.width / maskExtent.width
        let scaleY = targetExtent.height / maskExtent.height
        
        return mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY)).cropped(to: targetExtent)
    }
}
