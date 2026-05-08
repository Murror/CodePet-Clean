import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Profile")
                    .font(.pixelSystem(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                YourPetSection()

                LanguageStyleSection()
            }
            .padding(20)
        }
        .background(Color(hex: "#F7F5FC"))
    }
}

// MARK: - Your Pet Section

struct YourPetSection: View {
    @EnvironmentObject var appState: AppState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Pet")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(alignment: .leading, spacing: 12) {
                Text("Switch companions any time. Your progress stays.")
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PetCharacter.starters, id: \.self) { charId in
                        if let char = PetCharacter.all[charId] {
                            PetGridCell(
                                character: char,
                                isSelected: appState.activeChar == charId,
                                action: {
                                    SoundManager.shared.playCharSelect()
                                    appState.activeChar = charId
                                }
                            )
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E0DBEF"), lineWidth: 1))
        }
    }
}

private struct PetGridCell: View {
    let character: PetCharacter
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(character.color.opacity(isSelected ? 0.20 : (isHovered ? 0.14 : 0.08)))
                        .frame(height: 78)

                    CharacterImage(character.id, size: 60)
                        .charIdle(character.id)
                        .petBreathing()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? character.color : Color.clear, lineWidth: 2)
                )

                Text(character.name)
                    .font(.pixelSystem(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? character.color : Color(hex: "#2D2B26"))
                    .lineLimit(1)

                Text(character.domain)
                    .font(.pixelSystem(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Language Style Section

struct LanguageStyleSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Language Style")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose how the app talks to you. Switch any time.")
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    ForEach(LanguagePersona.allCases, id: \.self) { persona in
                        PersonaRow(
                            persona: persona,
                            isSelected: appState.languagePersona == persona,
                            action: { appState.languagePersona = persona }
                        )
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E0DBEF"), lineWidth: 1))
        }
    }
}

private struct PersonaRow: View {
    let persona: LanguagePersona
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(persona.icon)
                    .font(.pixelSystem(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.displayName)
                        .font(.pixelSystem(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(persona.blurb)
                        .font(.pixelSystem(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.pixelSystem(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#7B6BD8"))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? Color(hex: "#7B6BD8").opacity(0.10)
                          : (isHovered ? Color(hex: "#F7F5FC") : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(hex: "#7B6BD8") : Color(hex: "#E0DBEF"),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
