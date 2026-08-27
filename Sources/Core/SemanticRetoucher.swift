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

/// Módulo de Edição Semântica com Suavização de Borda (Feathering 100% Aveludado sem Degraus ou Blocos)
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
    
    /// Aplica tratamento fotográfico cirúrgico com transição 100% aveludada
    public func applySelectiveRetouch(to inputImage: CIImage, mattes: SemanticMattes, settings: EnhancementSettings) -> CIImage {
        guard settings.enableSemanticRetouch && mattes.hasAnyMatte else {
            return inputImage
        }
        
        var currentImage = inputImage
        let targetExtent = inputImage.extent
        let maxDim = max(targetExtent.width, targetExtent.height)
        let resScale = Float(max(1.0, maxDim / 1800.0))
        
        // 1. CABELO & BARBA
        if let hairMask = mattes.hair, settings.hairDetailBoost > 0.01 {
            let smoothedMask = refineAndSmoothMask(mask: hairMask, targetExtent: targetExtent, blurRadius: 4.0 * resScale)
            let hairEnhanced = currentImage.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.0 * resScale,
                kCIInputIntensityKey: settings.hairDetailBoost * 0.60
            ]).cropped(to: targetExtent)
            
            currentImage = hairEnhanced.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: smoothedMask
            ])
        }
        
        // 2. PELE HUMANA
        if let skinMask = mattes.skin, settings.skinSmoothing > 0.01 {
            let smoothedMask = refineAndSmoothMask(mask: skinMask, targetExtent: targetExtent, blurRadius: 8.0 * resScale)
            let smoothedSkin = currentImage.clampedToExtent().applyingFilter("CIBilateralFilter", parameters: [
                kCIInputRadiusKey: (1.8 + (settings.skinSmoothing * 2.0)) * resScale,
                "inputDistanceSigma": 0.08
            ]).cropped(to: targetExtent)
            
            let warmSkin = smoothedSkin.applyingFilter("CIVibrance", parameters: [
                "inputAmount": 0.04
            ])
            
            currentImage = warmSkin.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: smoothedMask
            ])
        }
        
        // 3. CÉU & NUVENS (Com Feathering Amplo para eliminar 100% dos blocos ou degraus no céu)
        if let skyMask = mattes.sky, settings.skyEnhancement > 0.01 {
            // Suavização ampla de 24px para garantir que a máscara do céu seja completamente difusa
            let ultraSmoothSkyMask = refineAndSmoothMask(mask: skyMask, targetExtent: targetExtent, blurRadius: 28.0 * resScale)
            
            let enhancedSky = currentImage.applyingFilter("CIVibrance", parameters: [
                "inputAmount": settings.skyEnhancement * 0.15
            ])
            
            currentImage = enhancedSky.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: ultraSmoothSkyMask
            ])
        }
        
        // 4. DENTES & SORRISO
        if let teethMask = mattes.teeth, settings.teethBrightening > 0.01 {
            let smoothedMask = refineAndSmoothMask(mask: teethMask, targetExtent: targetExtent, blurRadius: 3.0 * resScale)
            let whitenedTeeth = currentImage.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: settings.teethBrightening * 0.06,
                kCIInputSaturationKey: 1.0 - (settings.teethBrightening * 0.25)
            ])
            currentImage = whitenedTeeth.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: smoothedMask
            ])
        }
        
        // 5. ÓCULOS & ARMAÇÕES
        if let glassesMask = mattes.glasses, settings.glassesClarity > 0.01 {
            let smoothedMask = refineAndSmoothMask(mask: glassesMask, targetExtent: targetExtent, blurRadius: 3.0 * resScale)
            let sharpGlasses = currentImage.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.2 * resScale,
                kCIInputIntensityKey: settings.glassesClarity * 0.40
            ]).cropped(to: targetExtent)
            
            currentImage = sharpGlasses.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: smoothedMask
            ])
        }
        
        // 6. PROFUNDIDADE / BOKEH ÓPTICO
        if let depthMask = mattes.depth, settings.opticalBokehDepth > 0.01 {
            let smoothedMask = refineAndSmoothMask(mask: depthMask, targetExtent: targetExtent, blurRadius: 16.0 * resScale)
            let backgroundMask = smoothedMask.applyingFilter("CIColorInvert")
            
            let blurredBackground = currentImage.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: settings.opticalBokehDepth * 3.5 * resScale
            ]).cropped(to: targetExtent)
            
            currentImage = blurredBackground.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: currentImage,
                kCIInputMaskImageKey: backgroundMask
            ])
        }
        
        return currentImage
    }
    
    /// Redimensiona e aplica Feathering / Suavização Gaussiana nas bordas da máscara
    private func refineAndSmoothMask(mask: CIImage, targetExtent: CGRect, blurRadius: Float) -> CIImage {
        let maskExtent = mask.extent
        guard maskExtent.width > 0 && maskExtent.height > 0 else { return mask }
        
        let scaleX = targetExtent.width / maskExtent.width
        let scaleY = targetExtent.height / maskExtent.height
        let scaledMask = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY)).cropped(to: targetExtent)
        
        // Suavização Gaussiana com clampedToExtent para transição imperceptível e aveludada
        return scaledMask.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: blurRadius
        ]).cropped(to: targetExtent)
    }
}
