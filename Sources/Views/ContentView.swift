import SwiftUI
import PhotosUI

public struct ContentView: View {
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedDNGURL: URL? = nil
    
    @State private var originalPreview: UIImage? = nil
    @State private var enhancedPreview: UIImage? = nil
    @State private var isProcessing: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSavedAlert: Bool = false
    
    @State private var settings: EnhancementSettings = .default
    @State private var selectedPreset: String = "Leica Natural"
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ÁREA PRINCIPAL DE VISUALIZAÇÃO
                    if let original = originalPreview, let enhanced = enhancedPreview {
                        BeforeAfterView(originalImage: original, enhancedImage: enhanced)
                            .frame(maxWidth: .infinity)
                            .frame(height: 380)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    } else {
                        emptyStatePlaceholder
                    }
                    
                    // CONTROLES E AJUSTES
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            if selectedDNGURL != nil {
                                presetSelectorSection
                                adjustmentSlidersSection
                            }
                        }
                        .padding(16)
                    }
                    
                    // BARRA DE AÇÕES INFERIOR
                    bottomActionBar
                }
            }
            .navigationTitle("ProRAW Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedDNGURL != nil {
                        Button(action: resetToDefault) {
                            Text("Resetar")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
            }
            .alert("Foto Salva com Sucesso!", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A imagem com qualidade de câmera profissional foi salva na sua biblioteca de fotos.")
            }
            .onChange(of: selectedPhotoItem) { _ in
                loadSelectedPhoto(selectedPhotoItem)
            }
            .onChange(of: settings) { _ in
                reprocessPreview()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStatePlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            Text("Selecione uma foto Apple ProRAW (.DNG)")
                .font(.system(size: 16, weight: .medium))
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
                        microContrast: 0.65,
                        toneDepth: 0.45,
                        highlightRollOff: 0.8,
                        shadowRichness: 0.2,
                        opticalGrain: 0.05,
                        colorVibrance: 0.1
                    ))
                    presetButton(title: "Arri Cinema", icon: "film", preset: EnhancementSettings(
                        microContrast: 0.4,
                        toneDepth: 0.7,
                        highlightRollOff: 0.95,
                        shadowRichness: 0.4,
                        opticalGrain: 0.35,
                        colorVibrance: 0.05
                    ))
                    presetButton(title: "Pure Sensor", icon: "camera.filters", preset: EnhancementSettings(
                        microContrast: 0.2,
                        toneDepth: 0.3,
                        highlightRollOff: 0.5,
                        shadowRichness: 0.1,
                        opticalGrain: 0.0,
                        colorVibrance: 0.0
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
    
    private var adjustmentSlidersSection: some View {
        VStack(spacing: 16) {
            sliderRow(title: "Micro-Contraste Óptico", value: $settings.microContrast, range: 0.0...1.0, icon: "scope")
            sliderRow(title: "Highlight Roll-Off (Luzes)", value: $settings.highlightRollOff, range: 0.0...1.0, icon: "sun.max")
            sliderRow(title: "Profundidade Tonal (Curva S)", value: $settings.toneDepth, range: 0.0...1.0, icon: "slider.vertical.3")
            sliderRow(title: "Riqueza de Sombras", value: $settings.shadowRichness, range: 0.0...1.0, icon: "moon.fill")
            sliderRow(title: "Grão Analógico de Sensor", value: $settings.opticalGrain, range: 0.0...1.0, icon: "circle.grid.3x3.fill")
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
            
            if selectedDNGURL != nil {
                Button(action: saveFullResolutionImage) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("Salvar em Alta")
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
    
    // MARK: - Processing Logic
    
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
                    guard let data = data else { return }
                    
                    // Salva temporariamente em arquivo para o CIRAWFilter ler
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_input.dng")
                    try? data.write(to: tempURL)
                    
                    self.selectedDNGURL = tempURL
                    self.reprocessPreview()
                    
                case .failure(let error):
                    print("Erro ao carregar foto: \(error)")
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func reprocessPreview() {
        guard let url = selectedDNGURL else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            // Renderiza preview em draft mode para velocidade instantânea
            let orig = ProRAWProcessor.shared.getOriginalRaw(dngURL: url, isDraft: true)
            let enh = ProRAWProcessor.shared.process(dngURL: url, settings: self.settings, isDraft: true)
            
            DispatchQueue.main.async {
                self.originalPreview = orig
                self.enhancedPreview = enh
                self.isProcessing = false
            }
        }
    }
    
    private func saveFullResolutionImage() {
        guard let url = selectedDNGURL else { return }
        isSaving = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Renderiza na resolução máxima (48MP/24MP/12MP nativo)
            if let fullResImage = ProRAWProcessor.shared.process(dngURL: url, settings: self.settings, isDraft: false) {
                PhotoManager.shared.saveToPhotoLibrary(image: fullResImage) { success, error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        if success {
                            self.showSavedAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSaving = false
                }
            }
        }
    }
}
