import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) var theme: ThemeManager.ThemeColors

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(greeting)\(appState.displayName.isEmpty ? "" : ", \(appState.displayName)")!")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(theme.textPrimary)

                            Text("Level \(appState.userLevel) • Tier \(appState.currentTier)")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            StreakFireView(streak: appState.streak)

                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(theme.accentGold)
                                    .font(.system(size: 12))
                                Text("\(appState.totalXP) XP")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Pet Area with breathing + glow
                    PetAreaView5(character: character, theme: theme)

                    // Energy Bar
                    EnergyBarView5(energy: appState.petEnergy, theme: theme)
                        .fadeUp()

                    // XP Progress
                    XPProgressView5(theme: theme)
                        .fadeUp()

                    // Daily Challenge
                    DailyChallengeCard5(theme: theme)
                        .fadeUp()

                    // Story Lore
                    StoryLoreCard5(theme: theme)
                        .fadeUp()

                    // World Map
                    WorldMapSection()
                        .fadeUp()

                    // Achievements
                    AchievementsSection()
                        .fadeUp()

                    // Quick Settings Row
                    QuickSettingsRow(theme: theme)

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
            .background(theme.background)
            .onAppear {
                SoundManager.shared.setPhase("home")
            }

            // Level Up Overlay
            if appState.showLevelUp {
                LevelUpOverlay(
                    level: appState.userLevel,
                    characterColor: character.color,
                    onDismiss: { appState.showLevelUp = false }
                )
            }
        }
    }
}

// MARK: - Scene Theme Data

struct SceneTheme {
    let name: String
    let sky: [Color]
    let border: Color
    let top: Color
    let left: Color
    let right: Color
    let highlight: Color
    let badgeColor: Color

    static func forTier(_ tier: Int) -> SceneTheme {
        switch tier {
        case 2:
            return SceneTheme(name: "The Molten Forge",
                sky: [Color(hex: "#F0D0C0"), Color(hex: "#F4DCC8"), Color(hex: "#F8E8D8"), Color(hex: "#F0E8E0")],
                border: Color(hex: "#D0A088"), top: Color(hex: "#E87850"),
                left: Color(hex: "#882818"), right: Color(hex: "#C04830"),
                highlight: Color(hex: "#F0A880"), badgeColor: Color(hex: "#B83820"))
        case 3:
            return SceneTheme(name: "The Frozen Spire",
                sky: [Color(hex: "#D0E4F4"), Color(hex: "#D8ECF8"), Color(hex: "#E4F2FC"), Color(hex: "#F0F8FE")],
                border: Color(hex: "#90B8D8"), top: Color(hex: "#88B8D8"),
                left: Color(hex: "#406888"), right: Color(hex: "#6898B8"),
                highlight: Color(hex: "#B8D8F0"), badgeColor: Color(hex: "#406888"))
        case 4:
            return SceneTheme(name: "The Eternal Garden",
                sky: [Color(hex: "#F8D8E8"), Color(hex: "#FBE4EE"), Color(hex: "#FCEEF4"), Color(hex: "#FEF6F8")],
                border: Color(hex: "#E8A8C0"), top: Color(hex: "#F8C8D8"),
                left: Color(hex: "#C87898"), right: Color(hex: "#E098B0"),
                highlight: Color(hex: "#FDE0EC"), badgeColor: Color(hex: "#C0607A"))
        default: // Tier 1 / Ice Haven
            return SceneTheme(name: "Ice Haven",
                sky: [Color(hex: "#C8E6F8"), Color(hex: "#DAF0FC"), Color(hex: "#E8F6FC"), Color(hex: "#EEF4F0")],
                border: Color(hex: "#B8D8E8"), top: Color(hex: "#D6EEF8"),
                left: Color(hex: "#8CB8CC"), right: Color(hex: "#B0D6E8"),
                highlight: Color(hex: "#E0F4FC"), badgeColor: Color(hex: "#5BA0B8"))
        }
    }
}

// MARK: - Pet Area (Isometric Scene)

struct PetAreaView5: View {
    let character: PetCharacter
    let theme: ThemeManager.ThemeColors
    @EnvironmentObject var appState: AppState
    @State private var showRadial = false
    @State private var reactionText: String? = nil
    @State private var greetingIndex: Int = 0
    @State private var showSpeechBubble = true

    private var sceneTheme: SceneTheme {
        SceneTheme.forTier(appState.currentTier)
    }

    var currentGreeting: String {
        guard !character.greeting.isEmpty else { return "Hello!" }
        return character.greeting[greetingIndex % character.greeting.count]
    }

    var body: some View {
        VStack(spacing: 12) {
            // Speech Bubble above scene
            if showSpeechBubble && !showRadial {
                Text(reactionText ?? currentGreeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    )
                    .transition(.opacity.combined(with: .scale))
            }

            // Isometric Scene
            ZStack {
                // Sky gradient background
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: sceneTheme.sky,
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(sceneTheme.border.opacity(0.4), lineWidth: 1.5)
                    )

                // Isometric platform
                IsometricPlatform(theme: sceneTheme)
                    .offset(y: 30)

                // Tier-specific decorations
                TierDecorations(tier: appState.currentTier, theme: sceneTheme)

                // Character on platform
                VStack(spacing: 0) {
                    CharacterImage(character.id, size: 70)
                        .charIdle(character.id)
                        .petBreathing()

                    // Character shadow
                    Ellipse()
                        .fill(sceneTheme.left.opacity(0.2))
                        .frame(width: 36, height: 8)
                        .blur(radius: 2)
                        .offset(y: -4)
                }
                .offset(y: 10)

                // Radial interaction menu
                if showRadial {
                    RadialMenu(
                        charColor: character.color,
                        onAction: { action in doPetAction(action) },
                        onDismiss: { withAnimation(.spring(response: 0.3)) { showRadial = false } }
                    )
                    .offset(y: 10)
                }

                // Zone badge (top left)
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(sceneTheme.badgeColor)
                                .frame(width: 8, height: 8)
                            Text(sceneTheme.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(sceneTheme.badgeColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )

                        Spacer()

                        // Tap hint
                        if !showRadial && reactionText == nil {
                            Text("Tap to interact")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(sceneTheme.badgeColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.8))
                                )
                        }
                    }
                    .padding(12)

                    Spacer()

                    // Name badge (bottom center)
                    Text("\(character.name) · Lv \(appState.userLevel)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(character.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )
                        .padding(.bottom, 12)
                }
                .frame(height: 280)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .onTapGesture {
                if !showRadial && reactionText == nil {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showRadial = true
                    }
                    SoundManager.shared.playTap()
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear { startGreetingRotation() }
    }

    private func doPetAction(_ action: String) {
        withAnimation(.spring(response: 0.3)) { showRadial = false }

        switch action {
        case "pet":
            appState.petEnergy = min(100, appState.petEnergy + 5)
            reactionText = currentGreeting
        case "feed":
            appState.petEnergy = min(100, appState.petEnergy + 15)
            reactionText = "Yum! Energy restored!"
        case "play":
            appState.petEnergy = min(100, appState.petEnergy + 8)
            reactionText = "That was fun!"
        case "train":
            reactionText = "Let's learn something new!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                appState.selectedTab = .skills
                reactionText = nil
            }
            return
        default: break
        }

        SoundManager.shared.playTap()

        // Clear reaction after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { reactionText = nil }
        }
    }

    private func startGreetingRotation() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            guard reactionText == nil && !showRadial else { return }
            withAnimation(.easeInOut(duration: 0.3)) { showSpeechBubble = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                greetingIndex = (greetingIndex + 1) % max(1, character.greeting.count)
                withAnimation(.easeInOut(duration: 0.3)) { showSpeechBubble = true }
            }
        }
    }
}

// MARK: - Isometric Platform

struct IsometricPlatform: View {
    let theme: SceneTheme

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h * 0.55

            // Shadow ellipse
            let shadow = Ellipse().path(in: CGRect(x: cx - 150, y: cy + 48, width: 300, height: 36))
            context.fill(shadow, with: .color(theme.left.opacity(0.12)))

            // Top face (diamond)
            var top = Path()
            top.move(to: CGPoint(x: cx, y: cy - 50))
            top.addLine(to: CGPoint(x: cx + 160, y: cy))
            top.addLine(to: CGPoint(x: cx, y: cy + 50))
            top.addLine(to: CGPoint(x: cx - 160, y: cy))
            top.closeSubpath()
            context.fill(top, with: .color(theme.top))
            context.stroke(top, with: .color(theme.border.opacity(0.4)), lineWidth: 1)

            // Left face
            var leftFace = Path()
            leftFace.move(to: CGPoint(x: cx - 160, y: cy))
            leftFace.addLine(to: CGPoint(x: cx, y: cy + 50))
            leftFace.addLine(to: CGPoint(x: cx, y: cy + 68))
            leftFace.addLine(to: CGPoint(x: cx - 160, y: cy + 18))
            leftFace.closeSubpath()
            context.fill(leftFace, with: .color(theme.left))

            // Right face
            var rightFace = Path()
            rightFace.move(to: CGPoint(x: cx + 160, y: cy))
            rightFace.addLine(to: CGPoint(x: cx, y: cy + 50))
            rightFace.addLine(to: CGPoint(x: cx, y: cy + 68))
            rightFace.addLine(to: CGPoint(x: cx + 160, y: cy + 18))
            rightFace.closeSubpath()
            context.fill(rightFace, with: .color(theme.right))

            // Highlight on top
            var hl = Path()
            hl.move(to: CGPoint(x: cx, y: cy - 40))
            hl.addLine(to: CGPoint(x: cx + 130, y: cy))
            hl.addLine(to: CGPoint(x: cx, y: cy + 40))
            hl.addLine(to: CGPoint(x: cx - 130, y: cy))
            hl.closeSubpath()
            context.fill(hl, with: .color(theme.highlight.opacity(0.4)))
        }
        .frame(height: 200)
    }
}

// MARK: - Tier Decorations

struct TierDecorations: View {
    let tier: Int
    let theme: SceneTheme

    var body: some View {
        ZStack {
            switch tier {
            case 2: earthDecorations
            case 3: waterDecorations
            case 4: fireDecorations
            default: iceDecorations
            }
        }
        .frame(height: 280)
    }

    // Ice Haven — crystals, snow trees, snowflakes
    private var iceDecorations: some View {
        ZStack {
            // Left crystal cluster
            IceCrystal(height: 50).offset(x: -140, y: 10)
            IceCrystal(height: 38).offset(x: -125, y: 20)
            IceCrystal(height: 30).offset(x: -155, y: 22)

            // Right crystal cluster
            IceCrystal(height: 48).offset(x: 135, y: 12)
            IceCrystal(height: 34).offset(x: 150, y: 20)

            // Snow trees
            SnowTree(scale: 1.0).offset(x: -90, y: 30)
            SnowTree(scale: 0.7).offset(x: 95, y: 28)
            SnowTree(scale: 0.5).offset(x: -170, y: 40)

            // Snow dots
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 3, height: 3)
                    .offset(
                        x: CGFloat([-80, 60, -30, 120, -150][i]),
                        y: CGFloat([-80, -60, -100, -70, -50][i])
                    )
            }
        }
    }

    // Molten Forge — volcano, lava, sparks
    private var earthDecorations: some View {
        ZStack {
            // Volcano silhouette (back)
            VStack {
                Spacer()
                ZStack(alignment: .top) {
                    // Volcano shape
                    Canvas { context, size in
                        var v = Path()
                        v.move(to: CGPoint(x: size.width / 2, y: 0))
                        v.addLine(to: CGPoint(x: size.width / 2 + 50, y: 60))
                        v.addLine(to: CGPoint(x: size.width / 2 - 50, y: 60))
                        v.closeSubpath()
                        context.fill(v, with: .color(Color(hex: "#703020")))

                        var v2 = Path()
                        v2.move(to: CGPoint(x: size.width / 2, y: 10))
                        v2.addLine(to: CGPoint(x: size.width / 2 + 38, y: 55))
                        v2.addLine(to: CGPoint(x: size.width / 2 - 38, y: 55))
                        v2.closeSubpath()
                        context.fill(v2, with: .color(Color(hex: "#883828")))
                    }
                    .frame(width: 200, height: 60)

                    // Glow at top
                    Ellipse()
                        .fill(Color(hex: "#FFD040").opacity(0.7))
                        .frame(width: 20, height: 10)
                        .blur(radius: 3)
                }
                .offset(y: -90)
            }

            // Ember particles
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#FFD040").opacity(0.5))
                    .frame(width: 3, height: 3)
                    .offset(
                        x: CGFloat([-40, 30, -10, 50][i]),
                        y: CGFloat([-60, -80, -100, -50][i])
                    )
            }
        }
    }

    // Frozen Spire — ice spires
    private var waterDecorations: some View {
        ZStack {
            IceCrystal(height: 60, color: Color(hex: "#88B8D8")).offset(x: -130, y: 5)
            IceCrystal(height: 75, color: Color(hex: "#5090C0")).offset(x: -110, y: -5)
            IceCrystal(height: 45, color: Color(hex: "#A8D0E8")).offset(x: -145, y: 15)
            IceCrystal(height: 55, color: Color(hex: "#88B8D8")).offset(x: 120, y: 8)
            IceCrystal(height: 70, color: Color(hex: "#6898B8")).offset(x: 140, y: -2)

            ForEach(0..<4, id: \.self) { i in
                Circle().fill(Color.white.opacity(0.6)).frame(width: 3, height: 3)
                    .offset(x: CGFloat([-60, 80, -20, 100][i]), y: CGFloat([-70, -90, -50, -80][i]))
            }
        }
    }

    // Eternal Garden — flowers, arches
    private var fireDecorations: some View {
        ZStack {
            // Flower bushes
            Ellipse().fill(Color(hex: "#E8A0C0")).frame(width: 40, height: 28).offset(x: -120, y: 30)
            Ellipse().fill(Color(hex: "#D090B0")).frame(width: 35, height: 24).offset(x: 125, y: 28)
            Ellipse().fill(Color(hex: "#F0B8D0")).frame(width: 28, height: 20).offset(x: -90, y: 40)

            // Petals floating
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(Color(hex: "#FFB0C8").opacity(0.5)).frame(width: 4, height: 4)
                    .offset(x: CGFloat([-50, 40, -80, 70, 10][i]), y: CGFloat([-70, -90, -40, -60, -100][i]))
            }
        }
    }
}

struct IceCrystal: View {
    var height: CGFloat = 40
    var color: Color = Color(hex: "#AEE2F5")

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let w = height * 0.3
            var p = Path()
            p.move(to: CGPoint(x: cx, y: 0))
            p.addLine(to: CGPoint(x: cx + w, y: height))
            p.addLine(to: CGPoint(x: cx - w, y: height))
            p.closeSubpath()
            context.fill(p, with: .color(color.opacity(0.85)))
        }
        .frame(width: height * 0.8, height: height)
    }
}

struct SnowTree: View {
    var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Snow cap
            Canvas { context, size in
                var tri = Path()
                tri.move(to: CGPoint(x: size.width / 2, y: 0))
                tri.addLine(to: CGPoint(x: size.width, y: size.height))
                tri.addLine(to: CGPoint(x: 0, y: size.height))
                tri.closeSubpath()
                context.fill(tri, with: .color(Color(hex: "#4A8848")))

                var snow = Path()
                snow.move(to: CGPoint(x: size.width / 2, y: 0))
                snow.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.45))
                snow.addLine(to: CGPoint(x: size.width * 0.3, y: size.height * 0.45))
                snow.closeSubpath()
                context.fill(snow, with: .color(Color.white.opacity(0.5)))
            }
            .frame(width: 24 * scale, height: 28 * scale)

            // Trunk
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "#5A7A60"))
                .frame(width: 4 * scale, height: 14 * scale)
        }
    }
}

// MARK: - Radial Interaction Menu

struct RadialMenu: View {
    let charColor: Color
    let onAction: (String) -> Void
    let onDismiss: () -> Void

    private let actions: [(action: String, label: String, icon: String, angle: Double)] = [
        ("pet", "Pet", "💛", -90),    // top
        ("feed", "Feed", "🍎", 0),     // right
        ("train", "Train", "📖", 90),  // bottom
        ("play", "Play", "🎾", 180),   // left
    ]

    var body: some View {
        ZStack {
            // Dismiss area
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            // Action buttons in circle
            ForEach(0..<actions.count, id: \.self) { i in
                let a = actions[i]
                let radius: CGFloat = 60
                let rad = a.angle * .pi / 180
                let x = cos(rad) * radius
                let y = sin(rad) * radius

                Button(action: { onAction(a.action) }) {
                    VStack(spacing: 1) {
                        Text(a.icon)
                            .font(.system(size: 16))
                        Text(a.label)
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    )
                    .overlay(
                        Circle()
                            .stroke(charColor.opacity(0.25), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .offset(x: x, y: y)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 200, height: 200)
    }
}

// MARK: - Energy Bar (Phase 5)

struct EnergyBarView5: View {
    let energy: Int
    let theme: ThemeManager.ThemeColors

    private var barColor: Color {
        if energy > 60 { return theme.accentGreen }
        if energy > 30 { return theme.accentGold }
        return theme.accentRed
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("ENERGY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textMuted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.energyBarTrack)

                    RoundedRectangle(cornerRadius: 5)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(energy) / 100)
                        .animation(.spring(response: 0.5), value: energy)
                }
            }
            .frame(height: 10)

            Text("\(energy)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(barColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadow, radius: 4, y: 1)
        )
        .padding(.horizontal, 20)
        .cardHover()
    }
}

// MARK: - XP Progress (Phase 5)

struct XPProgressView5: View {
    @EnvironmentObject var appState: AppState
    let theme: ThemeManager.ThemeColors

    private var xpForLevel: Int { appState.userLevel * 100 }
    private var xpPrev: Int { (appState.userLevel - 1) * 100 }
    private var xpInLevel: Int { appState.totalXP - xpPrev }
    private var xpNeeded: Int { xpForLevel - xpPrev }
    private var xpPct: Double { min(1.0, Double(xpInLevel) / Double(max(1, xpNeeded))) }

    private var charColor: Color {
        PetCharacter.all[appState.activeChar]?.color ?? .gray
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(charColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(appState.userLevel)")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading) {
                        Text("Level \(appState.userLevel)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                        Text("\(appState.totalXP) XP total")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(theme.textMuted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(xpInLevel) / \(xpNeeded) XP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(charColor)
                    Text("to Level \(appState.userLevel + 1)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(theme.textMuted)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.energyBarTrack)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(charColor)
                        .frame(width: geo.size.width * xpPct)
                        .animation(.spring(response: 0.6), value: xpPct)
                }
            }
            .frame(height: 12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadow, radius: 8, y: 2)
        )
        .padding(.horizontal, 20)
        .cardHover()
    }
}

// MARK: - Daily Challenge Card (Phase 5)

struct DailyChallengeCard5: View {
    @EnvironmentObject var appState: AppState
    let theme: ThemeManager.ThemeColors

    private var todaysChallenge: DailyChallenge {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let challenges = GameData.dailyChallenges
        return challenges[(dayOfYear - 1) % challenges.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Challenge")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.accentGold)
                Spacer()
                Text("\(todaysChallenge.xpReward) XP")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.accentGold.opacity(0.15))
                    .foregroundColor(theme.accentGold)
                    .cornerRadius(8)
            }

            Text(todaysChallenge.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text(todaysChallenge.description)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)

            if appState.dailyChallengeCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.accentGreen)
                    Text("Completed today!")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accentGreen)
                }
            } else {
                Button(action: {
                    SoundManager.shared.playLevelUp()
                    withAnimation {
                        appState.completeDailyChallenge(
                            xpReward: todaysChallenge.xpReward,
                            challengeId: todaysChallenge.id
                        )
                    }
                }) {
                    Text("Start Challenge")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.accentGold)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.accentGold.opacity(0.3), lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 20)
        .cardHover()
    }
}

// MARK: - Story Lore Card (Phase 5)

struct StoryLoreCard5: View {
    @EnvironmentObject var appState: AppState
    let theme: ThemeManager.ThemeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("The DevRealm")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#E8D5B5"))
                Spacer()
                Text("Chapter \(appState.currentTier)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }

            Text(loreText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "#B0A898"))
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.loreBackground)
        )
        .padding(.horizontal, 20)
        .cardHover()
    }

    private var loreText: String {
        switch appState.currentTier {
        case 1: return "The Null Cascade spreads through The Source. You arrived at Ice Haven through an undefined entry point — the last safe zone."
        case 2: return "The Molten Forge burns again. Fragments of memory are returning. The Frozen Spire's archives remain sealed in ice."
        case 3: return "Two kingdoms restored. The Null Cascade fights harder now. The Eternal Garden's withered branches need advanced skill."
        default: return "The final storm. Three kingdoms reclaimed, but The Storm Summit is where Null's corruption is strongest."
        }
    }
}

// MARK: - Quick Settings Row

struct QuickSettingsRow: View {
    @EnvironmentObject var appState: AppState
    let theme: ThemeManager.ThemeColors

    var body: some View {
        HStack(spacing: 12) {
            // Dark Mode Toggle
            Button(action: { appState.toggleDarkMode() }) {
                HStack(spacing: 6) {
                    Image(systemName: appState.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 12))
                    Text(appState.isDarkMode ? "Dark" : "Light")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadow, radius: 3, y: 1)
                )
            }
            .buttonStyle(.plain)

            // Sound Toggle
            Button(action: { appState.toggleSound() }) {
                HStack(spacing: 6) {
                    Image(systemName: appState.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 12))
                    Text(appState.soundEnabled ? "Sound On" : "Sound Off")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadow, radius: 3, y: 1)
                )
            }
            .buttonStyle(.plain)

            // Debug: Reset Onboarding
            Button(action: { appState.resetOnboarding() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                    Text("Reset Onboarding")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadow, radius: 3, y: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environment(\.theme, ThemeManager.shared.light)
}
