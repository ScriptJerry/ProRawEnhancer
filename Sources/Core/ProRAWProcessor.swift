import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

public struct EnhancementSettings: Equatable {
    public var microContrast: Float = 0.30         // Micro-contraste óptico natural (sem halos)
    public var toneDepth: Float = 0.40             // Curva tonal S fotográfica
    public var highlightRollOff: Float = 0.60       // Suavização das altas luzes
    public var shadowRichness: Float = 0.20         // Pretos aprofundados
    public var opticalGrain: Float = 0.0           // Grão desligado por padrão (ativa apenas se desejar)
    public var colorVibrance: Float = 0.12          // Vibração Display P3 16-bit
    
    // Configurações do Apple Neural Engine
    public var enableNeuralEngine: Bool = true     // Ativa a Restauração Neural
    public var neuralTextureDetail: Float = 0.40   // Reconstrução de textura orgânica
    
    // Configurações de Máscaras Semânticas (IA ProRAW)
    public var enableSemanticRetouch: Bool = true  // Ativa o Retoque Semântico por IA
    public var hairDetailBoost: Float = 0.40       // Nitidez Natural em Cabelo e Barba
    public var skinSmoothing: Float = 0.30         // Retoque Orgânico de Pele
    public var skyEnhancement: Float = 0.30        // Céu com gradiente suave
    public var teethBrightening: Float = 0.25      // Clareamento Natural de Sorriso
    public var glassesClarity: Float = 0.30        // Claridade em Óculos
    public var opticalBokehDepth: Float = 0.25     // Desfoque Óptico de Fundo (Bokeh)
    
    public static let `default` = EnhancementSettings()
}

public final class ProRAWProcessor {
    public static let shared = ProRAWProcessor()
    
    private let ciContext: CIContext
    
    private init() {
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        
        // Configuração de Precisão de 16-Bit Half Float (RGBAh):
        // Elimina posterização, quadriculados no céu e mantém o alcance dinâmico de 12/14-bits do ProRAW
        self.ciContext = CIContext(options: [
            .workingFormat: CIFormat.RGBAh,
            .workingColorSpace: p3ColorSpace,
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
    }
    
    /// Processa a imagem aplicando o pipeline de alta fidelidade óptica de 16-bits
    public func process(inputImage: CIImage, mattes: SemanticMattes = SemanticMattes(), settings: EnhancementSettings = .default, isDraft: Bool = false) -> UIImage? {
        var currentImage = inputImage
        
        let extent = inputImage.extent
        let maxDim = max(extent.width, extent.height)
        let resScale = Float(max(1.0, maxDim / 1800.0))
        
        // 1. RESTAURAÇÃO NEURAL DE TEXTURA (Calibrada e sem halos)
        if settings.enableNeuralEngine {
            currentImage = NeuralEngineRestorer.shared.enhanceTexture(ciImage: currentImage, intensity: settings.neuralTextureDetail)
        }
        
        // 2. RETOQUE SEMÂNTICO CIRÚRGICO POR IA
        if settings.enableSemanticRetouch && mattes.hasAnyMatte {
            currentImage = SemanticRetoucher.shared.applySelectiveRetouch(to: currentImage, mattes: mattes, settings: settings)
        }
        
        // 3. MICRO-CONTRASTE ÓPTICO (Controlado com Clamp to Extent para zerar brilho na moldura)
        if settings.microContrast > 0.01 {
            let radius = (isDraft ? 0.9 : 1.4) * resScale
            let intensity = settings.microContrast * 0.55
            currentImage = currentImage.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: radius,
                kCIInputIntensityKey: intensity
            ]).cropped(to: extent)
        }
        
        // 4. CURVA TONAL FOTOGRÁFICA (Highlight Roll-off Suave & Profundidade 3D)
        let s = CGFloat(settings.toneDepth)
        let rollOff = CGFloat(settings.highlightRollOff)
        let shadow = CGFloat(settings.shadowRichness)
        
        let p0 = CIVector(x: 0.0, y: 0.0)
        let p1 = CIVector(x: 0.25, y: max(0.0, 0.25 - (shadow * 0.06)))
        let p2 = CIVector(x: 0.50, y: 0.50 + (s * 0.03))
        let p3 = CIVector(x: 0.75, y: min(1.0, 0.75 + (s * 0.02)))
        let p4 = CIVector(x: 1.0, y: 1.0 - (rollOff * 0.05))
        
        currentImage = currentImage.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": p0,
            "inputPoint1": p1,
            "inputPoint2": p2,
            "inputPoint3": p3,
            "inputPoint4": p4
        ])
        
        // 5. COLOR SCIENCE / VIBRAÇÃO P3 (16-bit)
        if abs(settings.colorVibrance) > 0.01 {
            currentImage = currentImage.applyingFilter("CIVibrance", parameters: [
                "inputAmount": settings.colorVibrance
            ])
        }
        
        // 6. GRÃO ÓPTICO DE SENSOR (Apenas se o usuário aumentar o slider)
        if settings.opticalGrain > 0.01 && !isDraft {
            currentImage = applyFastGrain(to: currentImage, amount: settings.opticalGrain)
        }
        
        // Renderização acelerada em 16-bit Display P3
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        if let cgImage = ciContext.createCGImage(currentImage, from: extent, format: .RGBA8, colorSpace: p3ColorSpace) {
            return UIImage(cgImage: cgImage)
        }
        
        return nil
    }
    
    /// Carrega e processa a imagem do arquivo com suporte a 16-bits
    public func loadCIImage(from url: URL, maxDimension: CGFloat? = nil) -> (original: CIImage, cleanRaw: CIImage, mattes: SemanticMattes)? {
        var baseCIImage: CIImage?
        var mattes = SemanticMattes()
        
        if let rawFilter = CIRAWFilter(imageURL: url) {
            rawFilter.sharpnessAmount = 0.0
            rawFilter.luminanceNoiseReductionAmount = 0.12
            rawFilter.colorNoiseReductionAmount = 0.80
            rawFilter.boostAmount = 0.0
            baseCIImage = rawFilter.outputImage
            mattes = SemanticRetoucher.shared.extractMattes(from: rawFilter)
        } else {
            baseCIImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
        }
        
        guard var image = baseCIImage else { return nil }
        
        if let maxDim = maxDimension {
            let extent = image.extent
            let currentMax = max(extent.width, extent.height)
            if currentMax > maxDim {
                let scale = maxDim / currentMax
                image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
        }
        
        return (original: image, cleanRaw: image, mattes: mattes)
    }
    
    public func renderUIImage(from ciImage: CIImage) -> UIImage? {
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: p3ColorSpace) else {
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
            kCIInputContrastKey: 1.1
        ])
        
        let opacity = CGFloat(amount * 0.08)
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
