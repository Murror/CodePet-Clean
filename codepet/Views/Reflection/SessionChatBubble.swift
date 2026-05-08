import SwiftUI

struct SessionChatBubble: View {
    @EnvironmentObject var appState: AppState

    let onTap: () -> Void

    @State private var float = false

    private var pet: PetCharacter? { PetCharacter.all[appState.activeChar] }
    private var petColor: Color { pet?.color ?? CodepetTheme.accentPurple }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(petColor.opacity(0.18))

                if let pet = pet {
                    Image(pet.imageName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(8)
                }
            }
            .frame(width: 60, height: 60)
            .codepetShadow(CodepetTheme.Shadow(
                color: petColor.opacity(0.35),
                radius: 14, x: 0, y: 6
            ))
            .offset(y: float ? -3 : 0)
        }
        .buttonStyle(.plain)
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            float = true
        }
    }
}
