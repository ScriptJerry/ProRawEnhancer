import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

public struct EnhancementSettings: Equatable {
    public var microContrast: Float = 0.5          // Realce de textura óptica fina
    public var toneDepth: Float = 0.6              // Curva tonal S cinematográfica
    public var highlightRollOff: Float = 0.7        // Suavização das altas luzes
    public var shadowRichness: Float = 0.3          // Pretos aprofundados
    public var opticalGrain: Float = 0.15           // Grão de sensor analógico
    public var colorVibrance: Float = 0.15          // Vibração Display P3
    public var enableNeuralEngine: Bool = true      // Ativa o Neural Engine / Restauração Profunda
    public var neuralTextureDetail: Float = 0.70    // Intensidade da reconstrução de textura
    
    public static let `default` = EnhancementSettings()
}

public final class ProRAWProcessor {
    public static let shared = ProRAWProcessor()
    
    private let ciContext: CIContext
    
    private init() {
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        self.ciContext = CIContext(options: [
            .workingColorSpace: colorSpace,
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
    }
    
    /// Processa a imagem aplicando o pipeline óptico + restauração por hardware Neural Engine
    public func process(inputImage: CIImage, settings: EnhancementSettings = .default, isDraft: Bool = false) -> UIImage? {
        var currentImage = inputImage
        
        // 1. RESTAURAÇÃO NEURAL DE TEXTURA (Neural Engine / Hardware Acceleration)
        if settings.enableNeuralEngine && !isDraft {
            currentImage = NeuralEngineRestorer.shared.enhanceTexture(ciImage: currentImage, intensity: settings.neuralTextureDetail)
        }
        
        // 2. MICRO-CONTRASTE ÓPTICO (Realce de frequências médias)
        if settings.microContrast > 0.01 {
            let radius: Float = isDraft ? 0.8 : 1.1
            let intensity = settings.microContrast * 0.75
            currentImage = currentImage.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: radius,
                kCIInputIntensityKey: intensity
            ])
        }
        
        // 3. CURVA TONAL CINEMATOGRÁFICA (Highlight Roll-off & Profundidade 3D)
        let s = CGFloat(settings.toneDepth)
        let rollOff = CGFloat(settings.highlightRollOff)
        let shadow = CGFloat(settings.shadowRichness)
        
        let p0 = CIVector(x: 0.0, y: 0.0)
        let p1 = CIVector(x: 0.25, y: max(0.0, 0.25 - (shadow * 0.08)))
        let p2 = CIVector(x: 0.50, y: 0.50 + (s * 0.05))
        let p3 = CIVector(x: 0.75, y: min(1.0, 0.75 + (s * 0.04)))
        let p4 = CIVector(x: 1.0, y: 1.0 - (rollOff * 0.07))
        
        currentImage = currentImage.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": p0,
            "inputPoint1": p1,
            "inputPoint2": p2,
            "inputPoint3": p3,
            "inputPoint4": p4
        ])
        
        // 4. COLOR SCIENCE / VIBRAÇÃO P3
        if abs(settings.colorVibrance) > 0.01 {
            currentImage = currentImage.applyingFilter("CIVibrance", parameters: [
                "inputAmount": settings.colorVibrance
            ])
        }
        
        // 5. GRÃO ÓPTICO DE SENSOR (Textura orgânica de filme)
        if settings.opticalGrain > 0.01 && !isDraft {
            currentImage = applyFastGrain(to: currentImage, amount: settings.opticalGrain)
        }
        
        guard let cgImage = ciContext.createCGImage(currentImage, from: currentImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Carrega e processa a imagem do arquivo (DNG RAW com desativação de filtros ou imagem normal)
    public func loadCIImage(from url: URL, maxDimension: CGFloat? = nil) -> (original: CIImage, cleanRaw: CIImage)? {
        var baseCIImage: CIImage?
        
        // Tenta carregar como RAW nativo via CIRAWFilter
        if let rawFilter = CIRAWFilter(imageURL: url) {
            rawFilter.sharpnessAmount = 0.0
            rawFilter.luminanceNoiseReductionAmount = 0.10
            rawFilter.colorNoiseReductionAmount = 0.75
            rawFilter.boostAmount = 0.0
            baseCIImage = rawFilter.outputImage
        } else {
            // Fallback para imagem padrão (JPEG/HEIC/PNG)
            baseCIImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
        }
        
        guard var image = baseCIImage else { return nil }
        
        // Otimização de escala para o preview ao vivo
        if let maxDim = maxDimension {
            let extent = image.extent
            let currentMax = max(extent.width, extent.height)
            if currentMax > maxDim {
                let scale = maxDim / currentMax
                image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
        }
        
        return (original: image, cleanRaw: image)
    }
    
    public func renderUIImage(from ciImage: CIImage) -> UIImage? {
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    private func applyFastGrain(to inputImage: CIImage, amount: Float) -> CIImage {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return inputImage
        }
        
        let extent = inputImage.extent
        let croppedNoise = noise.cropped(to: extent)
        let monoNoise = croppedNoise.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.2
        ])
        
        let opacity = CGFloat(amount * 0.12)
        let alphaMask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: opacity)).cropped(to: extent)
        
        let blendedGrain = monoNoise.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: inputImage,
            kCIInputMaskImageKey: alphaMask
        ])
        
        return blendedGrain.applyingFilter("CISoftLightBlendMode", parameters: [
            kCIInputBackgroundImageKey: inputImage
        ])
    }
}
