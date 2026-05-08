import SwiftUI

struct SessionChatBubble: View {
    @EnvironmentObject var appState: AppState

    let onTap: () -> Void

    @State private var float = false

    private var pet: PetCharacter? { PetCharacter.all[appState.activeChar] }
    private var petColor: Color { pet?.color ?? PixelTheme.outline }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let pet = pet {
                    Image(pet.imageName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(4)
                        .frame(width: 56, height: 56)
                        .background(Rectangle().fill(pet.color.opacity(0.20)))
                } else {
                    Rectangle()
                        .fill(petColor.opacity(0.30))
                        .frame(width: 56, height: 56)
                }
            }
            .pixelBorder()
            .pixelShadow(petColor, offset: float ? 5 : 3)
            .offset(y: float ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // 2-frame stepped float — snaps between positions instead of easing,
        // matching the discrete feel of pixel art.
        withAnimation(
            .linear(duration: 0.001)
                .repeatForever(autoreverses: true)
                .delay(1.4)
        ) {
            float = true
        }
    }
}
