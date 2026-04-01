import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.9

    var body: some View {
        ZStack {
            Color(hex: "#FBF9F1")
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Logo
                HStack(spacing: 0) {
                    Text("Code")
                        .font(.system(size: 46, weight: .heavy, design: .default))
                        .foregroundColor(Color(hex: "#2D2B26"))
                    Text("Pet")
                        .font(.system(size: 46, weight: .heavy, design: .default))
                        .foregroundColor(Color(hex: "#D4960A"))
                }

                Text("Your AI coding companions are waiting.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top, 20)
            }
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .onAppear {
            SoundManager.shared.playSplashIn()
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1
                scale = 1
            }
        }
    }
}

#Preview {
    SplashView()
}
