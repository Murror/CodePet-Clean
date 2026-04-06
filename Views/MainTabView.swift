import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showChat = false

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        HStack(spacing: 0) {
            // Custom narrow sidebar
            SidebarNav(
                selectedTab: $appState.selectedTab,
                showChat: $showChat,
                soundEnabled: $appState.soundEnabled,
                character: character,
                charColor: character.color,
                streak: appState.streak
            )

            // Divider line
            Rectangle()
                .fill(Color(hex: "#EBE8DF"))
                .frame(width: 1)

            // Main content
            ZStack {
                Group {
                    switch appState.selectedTab {
                    case .home:
                        HomeView()
                    case .skills:
                        SkillsView()
                    case .sessions:
                        SessionsView()
                    case .insights:
                        InsightsView()
                    case .profile:
                        ProfileView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Level-up overlay
                if appState.showLevelUp {
                    LevelUpOverlay(
                        level: appState.userLevel,
                        characterColor: character.color,
                        onDismiss: { appState.showLevelUp = false }
                    )
                }

                // Tier unlock overlay
                if appState.showTierUnlock {
                    TierUnlockOverlay(
                        tierNumber: appState.newTierNum,
                        characterId: appState.activeChar,
                        onDismiss: { appState.showTierUnlock = false }
                    )
                }
            }

            // Chat companion panel (right sidebar)
            if showChat {
                Rectangle()
                    .fill(Color(hex: "#EBE8DF"))
                    .frame(width: 1)

                CompanionPanelView(onClose: { withAnimation(.easeInOut(duration: 0.2)) { showChat = false } })
                    .frame(width: 280)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showChat)
        .onChange(of: appState.selectedTab) { newTab in
            SoundManager.shared.playTabSwitch()
            if newTab == .home {
                SoundManager.shared.setPhase("home")
            }
        }
    }
}

// MARK: - Custom Sidebar Navigation

struct SidebarNav: View {
    @Binding var selectedTab: AppState.Tab
    @Binding var showChat: Bool
    @Binding var soundEnabled: Bool
    let character: PetCharacter
    let charColor: Color
    let streak: Int

    private let mainTabs: [AppState.Tab] = [.home, .skills, .sessions, .insights]

    var body: some View {
        VStack(spacing: 2) {
            // Character avatar at top
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(charColor.opacity(0.07))
                    .frame(width: 44, height: 44)

                CharacterImage(character.id, size: 22)
                    .charIdle(character.id)
                    .petBreathing()
            }
            .padding(.bottom, 12)

            // Main nav items
            ForEach(mainTabs, id: \.self) { tab in
                NavButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    charColor: charColor,
                    action: { selectedTab = tab }
                )
            }

            Spacer()

            // Profile button
            NavButton(
                tab: .profile,
                isSelected: selectedTab == .profile,
                charColor: charColor,
                action: { selectedTab = .profile },
                customIcon: {
                    AnyView(
                        CharacterImage(character.id, size: 18)
                            .charIdle(character.id)
                    )
                }
            )

            // Chat toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { showChat.toggle() }
                SoundManager.shared.playTap()
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#6BCB77").opacity(0.15))
                            .frame(width: 24, height: 22)
                        Image(systemName: "ellipsis.bubble.fill")
                            .font(.system(size: 12))
                            .foregroundColor(showChat ? Color(hex: "#6BCB77") : Color(hex: "#B0A898"))
                    }
                    Text("Chat")
                        .font(.system(size: 8, weight: showChat ? .semibold : .regular, design: .monospaced))
                        .foregroundColor(showChat ? Color(hex: "#2D2B26") : Color(hex: "#B0A898"))
                }
                .frame(width: 56, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(showChat ? Color(hex: "#F0FAF4") : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            // Sound toggle
            Button(action: {
                soundEnabled.toggle()
                SoundManager.shared.isEnabled = soundEnabled
            }) {
                VStack(spacing: 4) {
                    Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(soundEnabled ? Color(hex: "#2D2B26") : Color(hex: "#CCC"))
                    Text(soundEnabled ? "Sound" : "Muted")
                        .font(.system(size: 7, weight: .regular, design: .monospaced))
                        .foregroundColor(soundEnabled ? Color(hex: "#2D2B26") : Color(hex: "#CCC"))
                }
                .frame(width: 56, height: 44)
                .opacity(0.6)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.vertical, 16)
        .frame(width: 72)
        .background(Color.white)
    }
}

// MARK: - Nav Button

struct NavButton: View {
    let tab: AppState.Tab
    let isSelected: Bool
    let charColor: Color
    let action: () -> Void
    var customIcon: (() -> AnyView)? = nil

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                // Active indicator bar (left edge)
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(charColor)
                        .frame(width: 3, height: 20)
                        .offset(x: -20)
                }

                VStack(spacing: 4) {
                    if let customIcon = customIcon {
                        customIcon()
                    } else {
                        NavIconView(tab: tab, isActive: isSelected)
                    }

                    Text(tab.rawValue)
                        .font(.system(size: 8, weight: isSelected ? .semibold : .regular, design: .monospaced))
                        .foregroundColor(isSelected ? Color(hex: "#2D2B26") : Color(hex: "#B0A898"))
                }
                .frame(width: 56, height: 52)
            }
            .frame(width: 56, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#F0FAF4") : isHovered ? Color(hex: "#FAFAF6") : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Pixel-Art Nav Icons (SwiftUI)

struct NavIconView: View {
    let tab: AppState.Tab
    let isActive: Bool

    var body: some View {
        Group {
            switch tab {
            case .home:
                HomeNavIcon(isActive: isActive)
            case .skills:
                SkillsNavIcon(isActive: isActive)
            case .sessions:
                SessionsNavIcon(isActive: isActive)
            case .insights:
                InsightsNavIcon(isActive: isActive)
            case .profile:
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? Color(hex: "#2D2B26") : Color(hex: "#B0A898"))
            }
        }
        .frame(width: 24, height: 24)
        .opacity(isActive ? 1.0 : 0.55)
    }
}

// Home icon — cute house with roof, door, windows
struct HomeNavIcon: View {
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            let s = size.width / 24

            // Roof
            var roofPath = Path()
            roofPath.move(to: CGPoint(x: 2 * s, y: 12 * s))
            roofPath.addLine(to: CGPoint(x: 12 * s, y: 3 * s))
            roofPath.addLine(to: CGPoint(x: 22 * s, y: 12 * s))
            roofPath.closeSubpath()
            context.fill(roofPath, with: .color(Color(hex: "#E8735A")))

            // Inner roof highlight
            var roofInner = Path()
            roofInner.move(to: CGPoint(x: 4 * s, y: 12 * s))
            roofInner.addLine(to: CGPoint(x: 12 * s, y: 5 * s))
            roofInner.addLine(to: CGPoint(x: 20 * s, y: 12 * s))
            roofInner.closeSubpath()
            context.fill(roofInner, with: .color(Color(hex: "#F4886E")))

            // House body
            let body = RoundedRectangle(cornerRadius: 1 * s).path(in: CGRect(x: 4 * s, y: 12 * s, width: 16 * s, height: 10 * s))
            context.fill(body, with: .color(Color(hex: "#FCE8C8")))
            context.stroke(body, with: .color(Color(hex: "#E6D5B5")), lineWidth: 0.8 * s)

            // Door
            let door = RoundedRectangle(cornerRadius: 3 * s).path(in: CGRect(x: 9.5 * s, y: 15 * s, width: 5 * s, height: 7 * s))
            context.fill(door, with: .color(Color(hex: "#E8735A")))
            let doorInner = RoundedRectangle(cornerRadius: 2 * s).path(in: CGRect(x: 10.5 * s, y: 16 * s, width: 3 * s, height: 5 * s))
            context.fill(doorInner, with: .color(Color(hex: "#D4604A")))

            // Door knob
            let knob = Circle().path(in: CGRect(x: 12.5 * s, y: 19 * s, width: 1 * s, height: 1 * s))
            context.fill(knob, with: .color(Color(hex: "#FCE8C8")))

            // Window left
            let winL = RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 5.5 * s, y: 13.5 * s, width: 3 * s, height: 3 * s))
            context.fill(winL, with: .color(Color(hex: "#AEE2F5")))
            context.stroke(winL, with: .color(Color(hex: "#E6D5B5")), lineWidth: 0.5 * s)

            // Window right
            let winR = RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 15.5 * s, y: 13.5 * s, width: 3 * s, height: 3 * s))
            context.fill(winR, with: .color(Color(hex: "#AEE2F5")))
            context.stroke(winR, with: .color(Color(hex: "#E6D5B5")), lineWidth: 0.5 * s)

            // Chimney
            let chimney = RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 17 * s, y: 4 * s, width: 3 * s, height: 6 * s))
            context.fill(chimney, with: .color(Color(hex: "#C4856C")))
            let chimneyCap = RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 16.5 * s, y: 3.5 * s, width: 4 * s, height: 1.5 * s))
            context.fill(chimneyCap, with: .color(Color(hex: "#D4967D")))
        }
    }
}

// Skills icon — tree with layered crown
struct SkillsNavIcon: View {
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            let s = size.width / 24

            // Trunk
            let trunk = RoundedRectangle(cornerRadius: 1 * s).path(in: CGRect(x: 10 * s, y: 14 * s, width: 4 * s, height: 9 * s))
            context.fill(trunk, with: .color(Color(hex: "#A0785A")))
            let trunkHighlight = RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 11 * s, y: 14 * s, width: 1.5 * s, height: 9 * s))
            context.fill(trunkHighlight, with: .color(Color(hex: "#B8906C").opacity(0.6)))

            // Crown layers (bottom to top)
            let crown1 = Ellipse().path(in: CGRect(x: 3 * s, y: 7 * s, width: 18 * s, height: 11 * s))
            context.fill(crown1, with: .color(Color(hex: "#6EAE5E")))
            let crown2 = Ellipse().path(in: CGRect(x: 5 * s, y: 4 * s, width: 14 * s, height: 9 * s))
            context.fill(crown2, with: .color(Color(hex: "#7EC06A")))
            let crown3 = Ellipse().path(in: CGRect(x: 7 * s, y: 2 * s, width: 10 * s, height: 7 * s))
            context.fill(crown3, with: .color(Color(hex: "#8ED47C")))

            // Highlights
            let h1 = Ellipse().path(in: CGRect(x: 8 * s, y: 3 * s, width: 4 * s, height: 3 * s))
            context.fill(h1, with: .color(Color(hex: "#A4E292").opacity(0.6)))

            // Fruits
            let fruit1 = Circle().path(in: CGRect(x: 6 * s, y: 10 * s, width: 2 * s, height: 2 * s))
            context.fill(fruit1, with: .color(Color(hex: "#F4886E")))
            let fruit2 = Circle().path(in: CGRect(x: 15 * s, y: 6 * s, width: 1.5 * s, height: 1.5 * s))
            context.fill(fruit2, with: .color(Color(hex: "#FCDE5A")))
        }
    }
}

// Sessions icon — book with spine, pages, bookmark
struct SessionsNavIcon: View {
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            let s = size.width / 24

            // Book back cover
            let back = RoundedRectangle(cornerRadius: 1.5 * s).path(in: CGRect(x: 4 * s, y: 3 * s, width: 16 * s, height: 18 * s))
            context.fill(back, with: .color(Color(hex: "#5B8C6E")))

            // Pages
            let pages = RoundedRectangle(cornerRadius: 1 * s).path(in: CGRect(x: 5.5 * s, y: 4 * s, width: 14 * s, height: 16 * s))
            context.fill(pages, with: .color(Color(hex: "#FFFEF8")))

            // Spine
            let spine = RoundedRectangle(cornerRadius: 1.5 * s).path(in: CGRect(x: 4 * s, y: 3 * s, width: 3.5 * s, height: 18 * s))
            context.fill(spine, with: .color(Color(hex: "#4A7A5C")))
            let spineEdge = Rectangle().path(in: CGRect(x: 5.8 * s, y: 3 * s, width: 1 * s, height: 18 * s))
            context.fill(spineEdge, with: .color(Color(hex: "#5B8C6E")))

            // Page lines
            for y in [8, 11, 14] {
                let line = RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 8.5 * s, y: CGFloat(y) * s, width: 9 * s, height: 0.8 * s))
                context.fill(line, with: .color(Color(hex: "#D8D4C8")))
            }

            // Bookmark ribbon
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: 15.5 * s, y: 3 * s))
            ribbon.addLine(to: CGPoint(x: 15.5 * s, y: 7 * s))
            ribbon.addLine(to: CGPoint(x: 16.5 * s, y: 6 * s))
            ribbon.addLine(to: CGPoint(x: 17.5 * s, y: 7 * s))
            ribbon.addLine(to: CGPoint(x: 17.5 * s, y: 3 * s))
            ribbon.closeSubpath()
            context.fill(ribbon, with: .color(Color(hex: "#E8735A")))
        }
    }
}

// Insights icon — bar chart with varying heights
struct InsightsNavIcon: View {
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            let s = size.width / 24

            // Base line
            let base = RoundedRectangle(cornerRadius: 0.5 * s).path(in: CGRect(x: 3 * s, y: 20 * s, width: 18 * s, height: 1 * s))
            context.fill(base, with: .color(Color(hex: "#D8D4C8")))

            // Bar 1 (short)
            let bar1 = RoundedRectangle(cornerRadius: 1 * s).path(in: CGRect(x: 4 * s, y: 14 * s, width: 3.5 * s, height: 6 * s))
            context.fill(bar1, with: .color(Color(hex: "#FCDE5A")))

            // Bar 2 (tall)
            let bar2 = RoundedRectangle(cornerRadius: 1 * s).path(in: CGRect(x: 8.5 * s, y: 7 * s, width: 3.5 * s, height: 13 * s))
            context.fill(bar2, with: .color(Color(hex: "#6BCB77")))

            // Bar 3 (medium)
            let bar3 = RoundedRectangle(cornerRadius: 1 * s).path(in: CGRect(x: 13 * s, y: 10 * s, width: 3.5 * s, height: 10 * s))
            context.fill(bar3, with: .color(Color(hex: "#5BA8C8")))

            // Bar 4 (tallest)
            let bar4 = RoundedRectangle(cornerRadius: 1 * s).path(in: CGRect(x: 17.5 * s, y: 4 * s, width: 3.5 * s, height: 16 * s))
            context.fill(bar4, with: .color(Color(hex: "#E8735A")))
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
