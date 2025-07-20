import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            // 應用程式圖示
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            // 應用程式標題
            VStack(spacing: 8) {
                Text("🐾 NekoDupImgFinder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("智能重複圖片搜尋器")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // 載入動畫
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(.circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    SplashView()
} 