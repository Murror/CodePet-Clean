import SwiftUI

struct SessionChatBubble: View {
    @EnvironmentObject var appState: AppState

    let onTap: () -> Void

    @State private var float = false
    @State private var glow: CGFloat = 0

    private var pet: PetCharacter? { PetCharacter.all[appState.activeChar] }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let pet = pet {
                    Circle()
                        .stroke(pet.color.opacity(0.35), lineWidth: 1.5)
                        .scaleEffect(1.0 + glow * 0.18)
                        .opacity(1.0 - glow * 0.7)
                        .frame(width: 56, height: 56)

                    Image(pet.imageName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(pet.color.opacity(0.18)))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(pet.color.opacity(0.55), lineWidth: 1.5))
                        .scaleEffect(float ? 1.02 : 0.98)
                        .offset(y: float ? -2 : 2)
                        .shadow(
                            color: pet.color.opacity(float ? 0.45 : 0.3),
                            radius: float ? 10 : 6,
                            x: 0, y: float ? 5 : 3
                        )
                } else {
                    Circle()
                        .fill(ReflectionTheme.accent.opacity(0.2))
                        .frame(width: 56, height: 56)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            float = true
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            glow = 1.0
        }
    }
}
