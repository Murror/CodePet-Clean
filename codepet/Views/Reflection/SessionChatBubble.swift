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
                    .fill(
                        LinearGradient(
                            colors: [ReflectionTheme.brandPurple, ReflectionTheme.brandPink],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                if let pet = pet {
                    Image(pet.imageName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(10)
                }
            }
            .frame(width: 56, height: 56)
            .codepetShadow(CodepetTheme.Shadow(
                color: ReflectionTheme.accent.opacity(0.4),
                radius: 16, x: 0, y: 6
            ))
            .offset(y: float ? -4 : 0)
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
