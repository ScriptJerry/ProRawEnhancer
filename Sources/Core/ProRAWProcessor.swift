import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

public struct EnhancementSettings: Equatable {
    public var microContrast: Float = 0.5      // Realce de textura óptica fina sem halos
    public var toneDepth: Float = 0.6          // Curva tonal S cinematográfica (estilo Arri/Sony)
    public var highlightRollOff: Float = 0.7    // Suavização da transição de altas luzes (evita estouro digital)
    public var shadowRichness: Float = 0.3      // Pretos aprofundados para volume 3D
    public var opticalGrain: Float = 0.2        // Grão de sensor analógico (substitui o aspecto plástico)
    public var colorVibrance: Float = 0.15      // Vibração seletiva em P3 Wide Gamut
    
    public static let `default` = EnhancementSettings()
}

public final class ProRAWProcessor {
    public static let shared = ProRAWProcessor()
    
    private let ciContext: CIContext
    
    private init() {
        // Usa Metal e o espaço de cor amplo Display P3 nativo do iPhone
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        self.ciContext = CIContext(options: [
            .workingColorSpace: colorSpace,
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
    }
    
    /// Processa o arquivo .DNG do Apple ProRAW removendo o processamento digital agressivo
    public func process(dngURL: URL, settings: EnhancementSettings = .default, isDraft: Bool = false) -> UIImage? {
        guard let rawFilter = CIRAWFilter(imageURL: dngURL) else {
            return nil
        }
        
        rawFilter.isDraftModeEnabled = isDraft
        
        // 1. DESATIVA O PÓS-PROCESSAMENTO AGRESSIVO DO SMARTPHONE
        rawFilter.sharpnessAmount = 0.0                  // Elimina halos brancos digitais
        rawFilter.noiseReductionAmount = 0.10             // Redução mínima para não empastar detalhes finos
        rawFilter.boostAmount = 0.0                      // Desativa o HDR achatado padrão da Apple
        rawFilter.colorNoiseReductionAmount = 0.75         // Limpa ruído de cor nas sombras
        
        guard var currentImage = rawFilter.outputImage else {
            return nil
        }
        
        // 2. MICRO-CONTRASTE ÓPTICO (Substitui a nitidez digital por acutância de lente profissional)
        if settings.microContrast > 0.01 {
            let intensity = settings.microContrast * 0.7
            currentImage = currentImage.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.1,                 // Raio ultra-pequeno para pegar apenas textura fina
                kCIInputIntensityKey: intensity
            ])
        }
        
        // 3. CURVA TONAL CINEMATOGRÁFICA (Highlight Roll-off & Profundidade 3D)
        let s = CGFloat(settings.toneDepth)
        let rollOff = CGFloat(settings.highlightRollOff)
        let shadow = CGFloat(settings.shadowRichness)
        
        // Curva S fotográfica personalizada com compressão suave de brancos
        let p0 = CIVector(x: 0.0, y: 0.0)
        let p1 = CIVector(x: 0.25, y: max(0.0, 0.25 - (shadow * 0.08)))      // Aprofundamento de sombras
        let p2 = CIVector(x: 0.50, y: 0.50 + (s * 0.04))                    // Equilíbrio de meios-tons
        let p3 = CIVector(x: 0.75, y: min(1.0, 0.75 + (s * 0.03)))          // Luzes preservadas
        let p4 = CIVector(x: 1.0, y: 1.0 - (rollOff * 0.06))                // Suavização do limite branco
        
        currentImage = currentImage.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": p0,
            "inputPoint1": p1,
            "inputPoint2": p2,
            "inputPoint3": p3,
            "inputPoint4": p4
        ])
        
        // 4. COLOR SCIENCE / VIBRAÇÃO P3 (Cores ricas sem saturar peles)
        if abs(settings.colorVibrance) > 0.01 {
            currentImage = currentImage.applyingFilter("CIVibrance", parameters: [
                "inputAmount": settings.colorVibrance
            ])
        }
        
        // 5. SIMULAÇÃO DE GRÃO ÓPTICO (Textura orgânica de sensor de cinema)
        if settings.opticalGrain > 0.01 && !isDraft {
            currentImage = applyOpticalGrain(to: currentImage, amount: settings.opticalGrain)
        }
        
        // Renderização final acelerada por GPU
        guard let cgImage = ciContext.createCGImage(currentImage, from: currentImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Gera uma imagem com o processamento padrão original da Apple para comparação
    public func getOriginalRaw(dngURL: URL, isDraft: Bool = false) -> UIImage? {
        guard let rawFilter = CIRAWFilter(imageURL: dngURL) else {
            return nil
        }
        
        rawFilter.isDraftModeEnabled = isDraft
        
        guard let originalImage = rawFilter.outputImage else {
            return nil
        }
        
        guard let cgImage = ciContext.createCGImage(originalImage, from: originalImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // Adiciona uma textura de micro-grão sutil
    private func applyOpticalGrain(to inputImage: CIImage, amount: Float) -> CIImage {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return inputImage
        }
        
        let croppedNoise = noise.cropped(to: inputImage.extent)
        
        // Converte o ruído para escala de cinza
        let monochromeNoise = croppedNoise.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputBrightnessKey: 0.0,
            kCIInputContrastKey: 1.1
        ])
        
        // Mistura sutilmente usando Soft Light
        let blended = monochromeNoise.applyingFilter("CISoftLightBlendMode", parameters: [
            kCIInputBackgroundImageKey: inputImage
        ])
        
        // Controla a opacidade do grão
        let opacity = CGFloat(amount * 0.18)
        return blended.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: inputImage,
            kCIInputMaskImageKey: CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: opacity)).cropped(to: inputImage.extent)
        ])
    }
}
