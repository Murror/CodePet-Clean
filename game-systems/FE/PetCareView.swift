import SwiftUI

/// Tamagotchi-style pet care screen with feeding, mood display, and status bars.
struct PetCareView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gameState: GameState
    @Environment(\.theme) var theme

    @State private var showFoodMenu = false
    @State private var selectedFood: PetFood? = nil
    @State private var petScale: CGFloat = 1.0
    @State private var isAnimating = false

    var currentCharacter: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var petMood: PetCare.Mood {
        let hoursSinceVisit = appState.lastVisit.map { Date().timeIntervalSince($0) / 3600 } ?? 0
        let justFed = selectedFood != nil && isAnimating
        return PetCare.calculateMood(
            energy: gameState.petHunger,
            hunger: gameState.petEnergy,
            streak: appState.streak,
            hoursSinceLastVisit: hoursSinceVisit,
            justFed: justFed
        )
    }

    var energyPercent: Double {
        Double(max(0, min(100, gameState.petEnergy))) / 100.0
    }

    var hungerPercent: Double {
        Double(max(0, min(100, gameState.petHunger))) / 100.0
    }

    var canAffordFood: [(PetFood, Bool)] {
        PetFood.all.map { food in
            (food, gameState.coins >= food.coinCost)
        }
    }

    var body: some View {
        ZStack {
            // Background
            theme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header: coin display
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Text("🪙")
                            .font(.system(size: 20))
                        Text("\(gameState.coins)")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.cardBackground)
                    .cornerRadius(8)
                    .padding(.trailing, 20)
                }

                // Pet card with character image and mood
                VStack(spacing: 16) {
                    // Character image
                    Image(currentCharacter.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128, height: 128)
                        .interpolation(.none)
                        .scaleEffect(petScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: petScale)

                    // Mood display
                    VStack(spacing: 6) {
                        Text(petMood.emoji)
                            .font(.system(size: 40))
                        Text(petMood.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        Text(petMood.description)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .background(theme.cardBackground)
                .cornerRadius(16)
                .shadow(color: theme.shadow, radius: 8, y: 2)
                .padding(.horizontal, 20)

                // Status bars
                VStack(spacing: 16) {
                    // Energy bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("⚡ ENERGY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text("\(gameState.petEnergy)/100")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.energyBarTrack)

                                // Fill (purple)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#7B6BD8"))
                                    .frame(width: geometry.size.width * energyPercent)
                            }
                        }
                        .frame(height: 8)
                    }

                    // Hunger bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("🍖 HUNGER")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text("\(gameState.petHunger)/100")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.energyBarTrack)

                                // Fill (orange)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#F5A623"))
                                    .frame(width: geometry.size.width * hungerPercent)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .padding(16)
                .background(theme.cardBackground)
                .cornerRadius(16)
                .shadow(color: theme.shadow, radius: 8, y: 2)
                .padding(.horizontal, 20)

                // Food menu
                if petMood != .asleep {
                    VStack(spacing: 12) {
                        Text("FEED YOUR PET")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(canAffordFood, id: \.0.id) { food, canAfford in
                                    FoodCardView(
                                        food: food,
                                        canAfford: canAfford,
                                        action: {
                                            if canAfford {
                                                feedPet(food)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                } else {
                    // Pet is asleep overlay
                    VStack(spacing: 12) {
                        Text("💤")
                            .font(.system(size: 40))
                        Text("Tap to wake up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .onTapGesture {
                        wakeUpPet()
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.vertical, 20)
        }
    }

    private func feedPet(_ food: PetFood) {
        if gameState.coins >= food.coinCost {
            gameState.feedPet(food: food, appState: appState)

            // Bounce animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                petScale = 1.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    petScale = 1.0
                }
            }
        }
    }

    private func wakeUpPet() {
        gameState.wakeUpPet()
    }
}

// MARK: - Food Card Component

private struct FoodCardView: View {
    @Environment(\.theme) var theme

    let food: PetFood
    let canAfford: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(food.emoji)
                    .font(.system(size: 28))

                Text(food.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 4) {
                    Text("+\(food.energyRestore)⚡")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    Text("+\(food.hungerRestore)🍖")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(Color(hex: "#7B6BD8"))

                HStack(spacing: 4) {
                    Text("🪙")
                    Text("\(food.coinCost)")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(canAfford ? theme.textPrimary : theme.textMuted)
            }
            .frame(width: 90)
            .padding(12)
            .background(theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: theme.shadow, radius: 4, y: 2)
            .opacity(canAfford ? 1.0 : 0.5)
        }
        .disabled(!canAfford)
    }
}

#Preview {
    PetCareView()
        .environmentObject(AppState())
        .environmentObject(GameState())
        .environment(\.theme, ThemeManager.shared.light)
}
