import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.uiLanguage) private var uiLanguage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(uiLanguage == .vi ? "Hồ sơ" : "Profile")
                    .font(.pixelSystem(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                AccountSection()

                YourPetSection()

                LanguageStyleSection()

                DisplayLanguageSection()

                DebugSection()
            }
            .padding(20)
        }
        .background(Color(hex: "#F7F5FC"))
    }
}

// MARK: - Account Section

struct AccountSection: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.uiLanguage) private var uiLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiLanguage == .vi ? "Tài khoản" : "Account")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(alignment: .leading, spacing: 14) {
                if let user = authManager.currentUser, !user.isAnonymous {
                    signedInBody(user)
                } else if authManager.isGuestMode {
                    guestBody
                } else {
                    notSignedInBody
                }
            }
            .padding(16)
            .pixelBox(fill: Color.white)
        }
    }

    // MARK: signed in

    @ViewBuilder
    private func signedInBody(_ user: User) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Live "online" status dot — pulsing green ring drawn manually.
            ZStack {
                Circle()
                    .fill(Color(hex: "#5DCAA5").opacity(0.20))
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color(hex: "#5DCAA5"))
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(uiLanguage == .vi ? "Đã đăng nhập" : "Signed in")
                    .font(.pixelSystem(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#3F8B6E"))
                    .tracking(0.6)
                Text(displayLabel(for: user))
                    .font(.pixelSystem(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .lineLimit(1)
                if let method = methodLabel() {
                    Text(method)
                        .font(.pixelSystem(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { authManager.signOut() }) {
                Text(uiLanguage == .vi ? "Đăng xuất" : "Sign out")
            }
            .buttonStyle(PixelButtonStyle(
                fill: Color(hex: "#E04040").opacity(0.12),
                foreground: Color(hex: "#C04040"),
                paddingH: 12,
                paddingV: 6,
                blockSize: 2,
                steps: 2,
                borderWidth: 2,
                shadowOffset: 2,
                font: .pixelSystem(size: 11, weight: .semibold)
            ))
        }
    }

    private func displayLabel(for user: User) -> String {
        if let email = user.email, !email.isEmpty { return email }
        if let name = user.displayName, !name.isEmpty { return name }
        return "Anonymous"
    }

    private func methodLabel() -> String? {
        switch authManager.authMethod {
        case "google": return "via Google"
        case "email":  return "via Email"
        case "pin":    return "via PIN"
        default:       return nil
        }
    }

    // MARK: guest

    private var guestBody: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FCDE5A").opacity(0.30))
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color(hex: "#FCDE5A"))
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Guest mode")
                    .font(.pixelSystem(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#A37B0A"))
                    .tracking(0.6)
                Text("Sign in to sync progress and chat")
                    .font(.pixelSystem(size: 12))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .lineLimit(2)
            }

            Spacer()

            Button(action: { authManager.isGuestMode = false }) {
                Text(uiLanguage == .vi ? "Đăng nhập" : "Sign in")
            }
            .buttonStyle(PixelButtonStyle(
                fill: Color(hex: "#7B6BD8"),
                foreground: .white,
                paddingH: 14,
                paddingV: 7,
                blockSize: 2,
                steps: 2,
                borderWidth: 2,
                shadowOffset: 2,
                font: .pixelSystem(size: 11, weight: .semibold)
            ))
        }
    }

    // MARK: signed out (edge case — routing usually keeps user on sign-in screen)

    private var notSignedInBody: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .stroke(Color.secondary, lineWidth: 1.5)
                .frame(width: 8, height: 8)
            Text(uiLanguage == .vi ? "Chưa đăng nhập" : "Not signed in")
                .font(.pixelSystem(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Your Pet Section

struct YourPetSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.uiLanguage) private var uiLanguage

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiLanguage == .vi ? "Pet của bạn" : "Your Pet")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(alignment: .leading, spacing: 12) {
                Text(uiLanguage == .vi
                     ? "Đổi pet bất cứ lúc nào. Tiến độ của bạn vẫn được giữ."
                     : "Switch companions any time. Your progress stays.")
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
            .pixelBox(fill: Color.white)
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
    @Environment(\.uiLanguage) private var uiLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiLanguage == .vi ? "Phong cách ngôn ngữ" : "Language Style")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(alignment: .leading, spacing: 12) {
                Text(uiLanguage == .vi
                     ? "Chọn cách app trò chuyện với bạn. Đổi bất cứ lúc nào."
                     : "Choose how the app talks to you. Switch any time.")
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
            .pixelBox(fill: Color.white)
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

// MARK: - Display Language Section

struct DisplayLanguageSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.uiLanguage) private var uiLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiLanguage == .vi ? "Ngôn ngữ hiển thị" : "Display Language")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(alignment: .leading, spacing: 12) {
                Text(uiLanguage == .vi
                     ? "Đổi ngôn ngữ hiển thị của app. Thay đổi áp dụng ngay lập tức."
                     : "Switch the app's display language. Changes are immediate.")
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(.secondary)

                Picker("", selection: $appState.uiLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text("\(lang.flag)  \(lang.displayName)").tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(16)
            .pixelBox(fill: Color.white)
        }
    }
}

// MARK: - Debug Section

struct DebugSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.uiLanguage) private var uiLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(uiLanguage == .vi ? "Gỡ lỗi" : "Debug")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            Toggle(isOn: $appState.demoModeEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(uiLanguage == .vi
                         ? "Chế độ Demo (Sprout × Byte)"
                         : "Demo Mode (Sprout × Byte)")
                        .font(.body)
                    Text(uiLanguage == .vi
                         ? "Thay tab Reflection bằng demo 13 phút có sẵn. ⌥1..⌥4 bắn milestone, ⌥5 hiện reflection, ⌥6..⌥8 health nudge, ⌥9 demo Tips, ⌥0 nhảy thẳng tới summary."
                         : "Replaces Reflection tab with hardcoded 13-min demo. ⌥1..⌥4 milestones, ⌥5 reflection, ⌥6..⌥8 health nudge, ⌥9 Tips demo, ⌥0 panic-skip.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .pixelBox(fill: Color.white)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
