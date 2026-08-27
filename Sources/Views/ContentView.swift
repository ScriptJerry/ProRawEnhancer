import SwiftUI
import PhotosUI

public struct ContentView: View {
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var currentImageURL: URL? = nil
    
    // Imagens base e máscaras semânticas em memória
    @State private var cachedPreviewCIImage: CIImage? = nil
    @State private var loadedMattes: SemanticMattes = SemanticMattes()
    @State private var originalPreviewUI: UIImage? = nil
    @State private var enhancedPreviewUI: UIImage? = nil
    
    @State private var isProcessing: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSavedAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @State private var settings: EnhancementSettings = .default
    @State private var selectedPreset: String = "Leica Natural"
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ÁREA PRINCIPAL DE PREVIEW COM SLIDER ANTES / DEPOIS
                    if let original = originalPreviewUI, let enhanced = enhancedPreviewUI {
                        BeforeAfterView(originalImage: original, enhancedImage: enhanced)
                            .frame(maxWidth: .infinity)
                            .frame(height: 380)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    } else if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Carregando ProRAW e extraindo mapas semânticos...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 380)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    } else {
                        emptyStatePlaceholder
                    }
                    
                    // CONTROLES E SLIDERS
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            if cachedPreviewCIImage != nil {
                                presetSelectorSection
                                semanticRetouchSection
                                neuralEngineSection
                                adjustmentSlidersSection
                            }
                        }
                        .padding(16)
                    }
                    
                    // BARRA INFERIOR DE EXPORTAÇÃO
                    bottomActionBar
                }
            }
            .navigationTitle("ProRAW Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if cachedPreviewCIImage != nil {
                        Button(action: resetToDefault) {
                            Text("Resetar")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
            }
            .alert("Aviso", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: selectedPhotoItem) { _ in
                loadSelectedPhoto(selectedPhotoItem)
            }
            .onChange(of: settings) { _ in
                updateLivePreview()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStatePlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            Text("Selecione uma foto da sua galeria")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Compatível com Apple ProRAW (.DNG) ou fotos normais")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Abrir Galeria", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var presetSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERFIS DE CÂMERA")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    presetButton(title: "Leica Natural", icon: "circle.circle", preset: .default)
                    presetButton(title: "Sony A7 Pro", icon: "sparkles", preset: EnhancementSettings(
                        microContrast: 0.75,
                        toneDepth: 0.45,
                        highlightRollOff: 0.85,
                        shadowRichness: 0.2,
                        opticalGrain: 0.05,
                        colorVibrance: 0.15,
                        enableNeuralEngine: true,
                        neuralTextureDetail: 0.80,
                        enableSemanticRetouch: true,
                        hairDetailBoost: 0.70,
                        skinSmoothing: 0.30,
                        skyEnhancement: 0.40,
                        teethBrightening: 0.35,
                        glassesClarity: 0.40,
                        opticalBokehDepth: 0.30
                    ))
                    presetButton(title: "Arri Cinema", icon: "film", preset: EnhancementSettings(
                        microContrast: 0.4,
                        toneDepth: 0.8,
                        highlightRollOff: 0.95,
                        shadowRichness: 0.45,
                        opticalGrain: 0.25,
                        colorVibrance: 0.05,
                        enableNeuralEngine: true,
                        neuralTextureDetail: 0.60,
                        enableSemanticRetouch: true,
                        hairDetailBoost: 0.50,
                        skinSmoothing: 0.45,
                        skyEnhancement: 0.50,
                        teethBrightening: 0.20,
                        glassesClarity: 0.30,
                        opticalBokehDepth: 0.45
                    ))
                    presetButton(title: "Pure Sensor", icon: "camera.filters", preset: EnhancementSettings(
                        microContrast: 0.1,
                        toneDepth: 0.2,
                        highlightRollOff: 0.4,
                        shadowRichness: 0.0,
                        opticalGrain: 0.0,
                        colorVibrance: 0.0,
                        enableNeuralEngine: false,
                        neuralTextureDetail: 0.0,
                        enableSemanticRetouch: false,
                        hairDetailBoost: 0.0,
                        skinSmoothing: 0.0,
                        skyEnhancement: 0.0,
                        teethBrightening: 0.0,
                        glassesClarity: 0.0,
                        opticalBokehDepth: 0.0
                    ))
                }
            }
        }
    }
    
    private func presetButton(title: String, icon: String, preset: EnhancementSettings) -> some View {
        let isSelected = selectedPreset == title
        return Button(action: {
            selectedPreset = title
            settings = preset
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
    
    private var semanticRetouchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settings.enableSemanticRetouch) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Retoque Semântico ProRAW")
                            .font(.system(size: 14, weight: .bold))
                        Text("Tratamento cirúrgico em 6 canais de IA")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.accentColor)
            
            if settings.enableSemanticRetouch {
                // Badges informando quais máscaras foram detectadas no ProRAW
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        matteBadge(title: "Pele", detected: loadedMattes.skin != nil)
                        matteBadge(title: "Cabelo", detected: loadedMattes.hair != nil)
                        matteBadge(title: "Céu", detected: loadedMattes.sky != nil)
                        matteBadge(title: "Sorriso", detected: loadedMattes.teeth != nil)
                        matteBadge(title: "Óculos", detected: loadedMattes.glasses != nil)
                        matteBadge(title: "Profundidade", detected: loadedMattes.depth != nil)
                    }
                }
                .padding(.vertical, 2)
                
                sliderRow(title: "Nitidez em Cabelos & Barba", value: $settings.hairDetailBoost, range: 0.0...1.0, icon: "comb.fill")
                sliderRow(title: "Retoque Orgânico de Pele", value: $settings.skinSmoothing, range: 0.0...1.0, icon: "face.smiling.inverse")
                sliderRow(title: "Céu & Nuvens (Polarizador)", value: $settings.skyEnhancement, range: 0.0...1.0, icon: "cloud.sun.fill")
                sliderRow(title: "Clareamento Natural de Sorriso", value: $settings.teethBrightening, range: 0.0...1.0, icon: "mouth.fill")
                sliderRow(title: "Claridade & Anti-Reflexo (Óculos)", value: $settings.glassesClarity, range: 0.0...1.0, icon: "eyeglasses")
                sliderRow(title: "Bokeh Óptico (Fundo Full Frame)", value: $settings.opticalBokehDepth, range: 0.0...1.0, icon: "camera.macro")
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func matteBadge(title: String, detected: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(detected ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(detected ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    private var neuralEngineSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $settings.enableNeuralEngine) {
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Neural Engine (IA)")
                            .font(.system(size: 14, weight: .bold))
                        Text("Restauração multi-escala de textura e acutância")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.accentColor)
            
            if settings.enableNeuralEngine {
                sliderRow(title: "Intensidade da Reconstrução Neural", value: $settings.neuralTextureDetail, range: 0.0...1.0, icon: "sparkles")
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var adjustmentSlidersSection: some View {
        VStack(spacing: 16) {
            sliderRow(title: "Micro-Contraste Óptico", value: $settings.microContrast, range: 0.0...1.0, icon: "scope")
            sliderRow(title: "Highlight Roll-Off (Luzes)", value: $settings.highlightRollOff, range: 0.0...1.0, icon: "sun.max")
            sliderRow(title: "Profundidade Tonal (Curva S)", value: $settings.toneDepth, range: 0.0...1.0, icon: "slider.vertical.3")
            sliderRow(title: "Riqueza de Sombras", value: $settings.shadowRichness, range: 0.0...1.0, icon: "moon.fill")
            sliderRow(title: "Vibração de Cor (P3)", value: $settings.colorVibrance, range: 0.0...0.5, icon: "paintpalette.fill")
            sliderRow(title: "Grão de Sensor (Filme)", value: $settings.opticalGrain, range: 0.0...0.5, icon: "circle.grid.3x3.fill")
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func sliderRow(title: String, value: Binding<Float>, range: ClosedRange<Float>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(String(format: "%.0f%%", value.wrappedValue * 100))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
                .tint(.accentColor)
        }
    }
    
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("Outra Foto")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundColor(.primary)
                .cornerRadius(14)
            }
            
            if cachedPreviewCIImage != nil {
                Button(action: saveFullResolutionImage) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                            Text("Processando...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Salvar Foto")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Core Processing Logic
    
    private func resetToDefault() {
        selectedPreset = "Leica Natural"
        settings = .default
    }
    
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        isProcessing = true
        
        _ = item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let data = data else {
                        self.isProcessing = false
                        return
                    }
                    
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("current_edit_input.dng")
                    try? data.write(to: tempURL)
                    self.currentImageURL = tempURL
                    
                    // Carrega a imagem e extrai todas as máscaras semânticas do ProRAW
                    DispatchQueue.global(qos: .userInteractive).async {
                        if let loaded = ProRAWProcessor.shared.loadCIImage(from: tempURL, maxDimension: 1200) {
                            let origUI = ProRAWProcessor.shared.renderUIImage(from: loaded.original)
                            let enhUI = ProRAWProcessor.shared.process(inputImage: loaded.cleanRaw, mattes: loaded.mattes, settings: self.settings, isDraft: true)
                            
                            DispatchQueue.main.async {
                                self.cachedPreviewCIImage = loaded.cleanRaw
                                self.loadedMattes = loaded.mattes
                                self.originalPreviewUI = origUI
                                self.enhancedPreviewUI = enhUI
                                self.isProcessing = false
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.isProcessing = false
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("Erro ao carregar foto: \(error)")
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func updateLivePreview() {
        guard let baseCI = cachedPreviewCIImage else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            let rendered = ProRAWProcessor.shared.process(inputImage: baseCI, mattes: self.loadedMattes, settings: self.settings, isDraft: true)
            DispatchQueue.main.async {
                self.enhancedPreviewUI = rendered
            }
        }
    }
    
    private func saveFullResolutionImage() {
        guard let url = currentImageURL else { return }
        isSaving = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Carrega em resolução máxima nativa extraindo todos os mapas semânticos
            if let fullResData = ProRAWProcessor.shared.loadCIImage(from: url, maxDimension: nil),
               let fullResExport = ProRAWProcessor.shared.process(inputImage: fullResData.cleanRaw, mattes: fullResData.mattes, settings: self.settings, isDraft: false) {
                
                PhotoManager.shared.saveToPhotoLibrary(image: fullResExport) { success, error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        if success {
                            self.alertMessage = "Foto processada com o Apple Neural Engine + Retoque Semântico em 6 Canais e salva com sucesso!"
                            self.showSavedAlert = true
                        } else {
                            self.alertMessage = "Erro ao salvar: \(error?.localizedDescription ?? "Permissão negada.")"
                            self.showSavedAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.alertMessage = "Não foi possível renderizar a imagem em alta resolução."
                    self.showSavedAlert = true
                }
            }
        }
    }
}
