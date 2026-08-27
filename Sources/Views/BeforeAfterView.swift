import SwiftUI

public struct BeforeAfterView: View {
    let originalImage: UIImage
    let enhancedImage: UIImage
    
    @State private var sliderPosition: CGFloat = 0.5
    
    public init(originalImage: UIImage, enhancedImage: UIImage) {
        self.originalImage = originalImage
        self.enhancedImage = enhancedImage
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let splitX = width * sliderPosition
            
            ZStack(alignment: .leading) {
                // 1. Imagem Aprimorada (Fundo Total)
                Image(uiImage: enhancedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                
                // 2. Imagem Original (Recortada à esquerda)
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: splitX, height: height)
                            Spacer(minLength: 0)
                        }
                    )
                
                // 3. Linha divisória com indicador de arrasto
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: height)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .offset(x: splitX - 1)
                
                // 4. Círculo do Slider
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    )
                    .offset(x: splitX - 16, y: height / 2 - 16)
                
                // 5. Badges informativas (Original vs Pro Camera)
                VStack {
                    HStack {
                        Text("ORIGINAL")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                            .opacity(sliderPosition > 0.15 ? 0.9 : 0.0)
                        
                        Spacer()
                        
                        Text("PRO CAMERA")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.9))
                            .clipShape(Capsule())
                            .foregroundColor(.black)
                            .opacity(sliderPosition < 0.85 ? 1.0 : 0.0)
                    }
                    .padding(12)
                    Spacer()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let locationX = value.location.x
                        sliderPosition = min(max(0, locationX / width), 1)
                    }
            )
            .clipped()
            .cornerRadius(16)
        }
    }
}
