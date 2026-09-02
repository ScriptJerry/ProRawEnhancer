import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit

public struct EnhancementSettings: Equatable {
    public var microContrast: Float = 0.30
    public var toneDepth: Float = 0.35
    public var highlightRollOff: Float = 0.60
    public var shadowRichness: Float = 0.15
    public var opticalGrain: Float = 0.0
    public var colorVibrance: Float = 0.12
    
    public var enableNeuralEngine: Bool = true
    public var neuralTextureDetail: Float = 0.75
    
    public var enableSemanticRetouch: Bool = true
    public var hairDetailBoost: Float = 0.40
    public var skinSmoothing: Float = 0.25
    public var skyEnhancement: Float = 0.25
    public var teethBrightening: Float = 0.20
    public var glassesClarity: Float = 0.25
    public var opticalBokehDepth: Float = 0.0
    
    public static let `default` = EnhancementSettings()
}

/// Estrutura que carrega a imagem SDR processada e o Gain Map original do ProRAW para HDR na saída HEIF
public struct ProcessedPhoto {
    public let sdrImage: CIImage             // Imagem processada pelo pipeline de cor
    public let gainMap: CIImage?             // Gain Map HDR original extraído do DNG (luminância extra)
    public let gainMapHeadroom: Float        // Headroom máximo em nits (tipicamente 4.0 = 1000 nits)
}

public final class ProRAWProcessor {
    public static let shared = ProRAWProcessor()
    
    private let ciContext: CIContext
    
    private init() {
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        
        self.ciContext = CIContext(options: [
            .workingFormat: CIFormat.RGBAh,
            .workingColorSpace: p3ColorSpace,
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
    }
    
    /// Processa a imagem com preview a 60fps (isDraft=true) ou com rede neural para exportação (isDraft=false)
    public func process(inputImage: CIImage, mattes: SemanticMattes = SemanticMattes(), settings: EnhancementSettings = .default, isDraft: Bool = false) -> UIImage? {
        let processed = processToCIImage(inputImage: inputImage, mattes: mattes, settings: settings, isDraft: isDraft)
        
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = ciContext.createCGImage(processed, from: processed.extent, format: .RGBA8, colorSpace: p3ColorSpace) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    /// Processa e devolve o CIImage + Gain Map preservado para exportação HDR
    public func processForExport(inputImage: CIImage, gainMap: CIImage?, gainMapHeadroom: Float, mattes: SemanticMattes, settings: EnhancementSettings) -> ProcessedPhoto {
        let processed = processToCIImage(inputImage: inputImage, mattes: mattes, settings: settings, isDraft: false)
        return ProcessedPhoto(sdrImage: processed, gainMap: gainMap, gainMapHeadroom: gainMapHeadroom)
    }
    
    private func processToCIImage(inputImage: CIImage, mattes: SemanticMattes, settings: EnhancementSettings, isDraft: Bool) -> CIImage {
        var currentImage = inputImage
        
        let extent = inputImage.extent
        let maxDim = max(extent.width, extent.height)
        let resScale = Float(max(1.0, maxDim / 2000.0))
        
        // 1. RESTAURAÇÃO NEURAL DE TEXTURA
        if settings.enableNeuralEngine {
            if isDraft {
                currentImage = NeuralEngineRestorer.shared.quickPreviewAcutance(ciImage: currentImage, intensity: settings.neuralTextureDetail)
            } else {
                currentImage = NeuralEngineRestorer.shared.enhanceTexture(ciImage: currentImage, intensity: settings.neuralTextureDetail)
            }
        }
        
        // 2. RETOQUE SEMÂNTICO CIRÚRGICO POR IA
        if settings.enableSemanticRetouch && mattes.hasAnyMatte {
            currentImage = SemanticRetoucher.shared.applySelectiveRetouch(to: currentImage, mattes: mattes, settings: settings)
        }
        
        // 3. MICRO-CONTRASTE ÓPTICO
        if settings.microContrast > 0.01 {
            let radius = (isDraft ? 1.2 : 2.0) * resScale
            let intensity = settings.microContrast * 0.45
            currentImage = currentImage.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: radius,
                kCIInputIntensityKey: intensity
            ]).cropped(to: extent)
        }
        
        // 4. CURVA TONAL FOTOGRÁFICA
        let s = CGFloat(settings.toneDepth)
        let rollOff = CGFloat(settings.highlightRollOff)
        let shadow = CGFloat(settings.shadowRichness)
        
        currentImage = currentImage.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0.0, y: 0.0),
            "inputPoint1": CIVector(x: 0.25, y: max(0.0, 0.25 - (shadow * 0.05))),
            "inputPoint2": CIVector(x: 0.50, y: 0.50 + (s * 0.025)),
            "inputPoint3": CIVector(x: 0.75, y: min(1.0, 0.75 + (s * 0.02))),
            "inputPoint4": CIVector(x: 1.0, y: 1.0 - (rollOff * 0.04))
        ])
        
        // 5. VIBRAÇÃO P3
        if abs(settings.colorVibrance) > 0.01 {
            currentImage = currentImage.applyingFilter("CIVibrance", parameters: ["inputAmount": settings.colorVibrance])
        }
        
        // 6. GRÃO (apenas no final, apenas se configurado)
        if settings.opticalGrain > 0.01 && !isDraft {
            currentImage = applyFastGrain(to: currentImage, amount: settings.opticalGrain)
        }
        
        return currentImage
    }
    
    /// Carrega o DNG extraindo imagem limpa, Gain Map HDR e máscaras semânticas
    public func loadCIImage(from url: URL, maxDimension: CGFloat? = nil) -> (original: CIImage, cleanRaw: CIImage, mattes: SemanticMattes, gainMap: CIImage?, gainMapHeadroom: Float)? {
        var baseCIImage: CIImage?
        var gainMap: CIImage? = nil
        var gainMapHeadroom: Float = 1.0
        var mattes = SemanticMattes()
        
        if let rawFilter = CIRAWFilter(imageURL: url) {
            rawFilter.sharpnessAmount = 0.0
            rawFilter.luminanceNoiseReductionAmount = 0.10
            rawFilter.colorNoiseReductionAmount = 0.75
            rawFilter.boostAmount = 0.0
            baseCIImage = rawFilter.outputImage
            mattes = SemanticRetoucher.shared.extractMattes(from: rawFilter)
            
            // Extrai o Gain Map HDR via CGImageSource (API pública correta no iOS 17+)
            if #available(iOS 17.0, *) {
                (gainMap, gainMapHeadroom) = Self.extractHDRGainMap(from: url)
            }
        } else {
            baseCIImage = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
            if #available(iOS 17.0, *) {
                (gainMap, gainMapHeadroom) = Self.extractHDRGainMap(from: url)
            }
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
        
        return (original: image, cleanRaw: image, mattes: mattes, gainMap: gainMap, gainMapHeadroom: gainMapHeadroom)
    }
    
    public func renderUIImage(from ciImage: CIImage) -> UIImage? {
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: p3ColorSpace) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    /// Renderiza o CIImage como HEIF de 10 bits com o Gain Map HDR embutido (iOS 17+)
    public func renderHEIFWithGainMap(from processedPhoto: ProcessedPhoto) -> Data? {
        guard #available(iOS 17.0, *) else { return nil }
        
        let p3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        let sdr = processedPhoto.sdrImage
        
        var options: [CIImageRepresentationOption: Any] = [
            .init(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.96
        ]
        
        // Embute o Gain Map HDR original na saída HEIF se disponível
        if let gainMap = processedPhoto.gainMap {
            options[.init(rawValue: "kCIImageRepresentationHDRGainMapImage")] = gainMap
            options[.init(rawValue: "kCIImageRepresentationMaximumHDRHeadroom")] = processedPhoto.gainMapHeadroom
        }
        
        return ciContext.heifRepresentation(
            of: sdr,
            format: .RGBA8,
            colorSpace: p3ColorSpace,
            options: options
        )
    }
    
    private func applyFastGrain(to inputImage: CIImage, amount: Float) -> CIImage {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return inputImage }
        let extent = inputImage.extent
        let monoNoise = noise.cropped(to: extent).applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.1
        ])
        let alphaMask = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(amount * 0.08))).cropped(to: extent)
        let blendedGrain = monoNoise.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: inputImage,
            kCIInputMaskImageKey: alphaMask
        ])
        return blendedGrain.applyingFilter("CISoftLightBlendMode", parameters: [
            kCIInputBackgroundImageKey: inputImage
        ])
    }
    
    /// Extrai o HDR Gain Map de qualquer arquivo de imagem usando CGImageSource (API pública oficial iOS 17+)
    @available(iOS 17.0, *)
    private static func extractHDRGainMap(from url: URL) -> (CIImage?, Float) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else {
            return (nil, 4.0)
        }
        
        // Tenta extrair o Gain Map como dado auxiliar de luminância HDR
        if let gainMapData = CGImageSourceCopyAuxiliaryDataInfoAtIndex(
            source, 0,
            kCGImageAuxiliaryDataTypeHDRGainMap as CFString
        ) as? [AnyHashable: Any],
           let gainMapPixelData = gainMapData[kCGImageAuxiliaryDataInfoData] as? Data,
           let gainMapDesc = gainMapData[kCGImageAuxiliaryDataInfoDataDescription] as? [AnyHashable: Any] {
            
            let width = gainMapDesc["Width"] as? Int ?? 0
            let height = gainMapDesc["Height"] as? Int ?? 0
            let headroom = gainMapDesc["MaximumContentHeadroom"] as? Float ?? 4.0
            
            if width > 0 && height > 0 {
                let provider = gainMapPixelData.withUnsafeBytes {
                    CGDataProvider(dataInfo: nil, data: $0.baseAddress!, size: gainMapPixelData.count) { _, _, _ in }
                }
                if let provider = provider,
                   let cgGainMap = CGImage(
                    width: width, height: height,
                    bitsPerComponent: 8, bitsPerPixel: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGBitmapInfo(rawValue: 0),
                    provider: provider,
                    decode: nil, shouldInterpolate: true,
                    intent: .defaultIntent
                   ) {
                    var gainMapImage = CIImage(cgImage: cgGainMap)
                    
                    // Extrai a orientação EXIF da imagem principal para alinhar perfeitamente o Gain Map e evitar distorção ou rotação incorreta
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                        var orientationVal: UInt32? = nil
                        if let o = properties[kCGImagePropertyOrientation as String] as? UInt32 {
                            orientationVal = o
                        } else if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
                                  let o = tiffDict[kCGImagePropertyTIFFOrientation as String] as? UInt32 {
                            orientationVal = o
                        }
                        
                        if let oVal = orientationVal, let orientation = CGImagePropertyOrientation(rawValue: oVal) {
                            gainMapImage = gainMapImage.oriented(orientation)
                        }
                    }
                    
                    return (gainMapImage, headroom)
                }
            }
        }
        
        return (nil, 4.0)
    }
}
