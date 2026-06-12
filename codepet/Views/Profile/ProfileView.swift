import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.uiLanguage) private var uiLanguage

    var body: some View {
        // Natural sizing — cards are content-sized, not stretched to fill the
        // viewport, so the progress cards don't tower over the stat cards.
        ScrollView {
            VStack(spacing: 20) {
                // Hero: identity (folds in Account status).
                ProfileHeroCard()

                // Key progress, surfaced right under the identity.
                ProfileStatsBento()

                // Settings as a dashboard: companion switcher + preferences.
                HStack(alignment: .top, spacing: 20) {
                    YourPetSection()
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    PreferencesSection()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                // Demo toggle, tucked into the bottom-left corner.
                HStack {
                    DebugSection()
                    Spacer()
                }
            }
            .padding(20)
        }
        .background(Color(hex: "#F7F5FC"))
    }
}

// MARK: - Profile Hero Card
//
// The "personal dashboard" header: the active pet avatar, the user's name, their
// account status (signed-in / guest / signed-out, with the matching action), and
// a brand-colored stat strip surfacing the numbers a learner tracks — level,
// streak, lessons, coins — plus an XP-to-next-level bar. The card is tinted to
// the chosen pet's color so the profile feels personal.

struct ProfileHeroCard: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.uiLanguage) private var uiLanguage

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var displayName: String {
        appState.displayName.isEmpty ? character.name : appState.displayName
    }

    /// Ties the user's identity to their chosen companion — the personalized
    /// touch. With a name set: "Coding with Nova · The Firestarter". Without one
    /// (name falls back to the pet), lead with the pet's badge + role instead so
    /// it doesn't read "Coding with Nova" next to a "Nova" headline.
    private var tagline: String {
        appState.displayName.isEmpty
            ? "\(character.badge) · \(character.domain)"
            : "Coding with \(character.name) · \(character.badge)"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Identity row
            HStack(spacing: 14) {
                // Static, contained portrait. The idle float/twitch + breathing
                // are built for the big Home pet scene; in this small tile they
                // just shove the sprite outside the rounded box. A fixed-size,
                // clipped tile frames every character consistently.
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(character.color.opacity(0.18))
                    CharacterImage(character.id, size: 58)
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(character.color.opacity(0.45), lineWidth: 2)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        // Standard font (not pixel) — renders names with
                        // diacritics (e.g. Vietnamese) cleanly.
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(tagline)
                        .font(.pixelSystem(size: 12, weight: .semibold))
                        .foregroundColor(character.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    statusLine
                }

                Spacer()

                actionButton
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [character.color.opacity(0.16), character.color.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(character.color.opacity(0.28), lineWidth: 2)
                )
                .shadow(color: character.color.opacity(0.12), radius: 10, y: 4)
        )
    }

    // MARK: account status (folded in from AccountSection)

    @ViewBuilder
    private var statusLine: some View {
        if let user = authManager.currentUser, !user.isAnonymous {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "#5DCAA5")).frame(width: 7, height: 7)
                Text(accountLabel(for: user))
                    .font(.pixelSystem(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                    .lineLimit(1)
            }
        } else if authManager.isGuestMode {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "#FCDE5A")).frame(width: 7, height: 7)
                Text(uiLanguage == .vi ? "Chế độ khách · đăng nhập để đồng bộ"
                                       : "Guest mode · sign in to sync")
                    .font(.pixelSystem(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                    .lineLimit(1)
            }
        } else {
            HStack(spacing: 6) {
                Circle().stroke(Color.secondary, lineWidth: 1.5).frame(width: 7, height: 7)
                Text(uiLanguage == .vi ? "Chưa đăng nhập" : "Not signed in")
                    .font(.pixelSystem(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let user = authManager.currentUser, !user.isAnonymous {
            Button(action: { authManager.signOut() }) {
                Text(uiLanguage == .vi ? "Đăng xuất" : "Sign out")
            }
            .buttonStyle(PixelButtonStyle(
                fill: Color(hex: "#E04040").opacity(0.12),
                foreground: Color(hex: "#C04040"),
                paddingH: 12, paddingV: 6, blockSize: 2, steps: 2,
                borderWidth: 2, shadowOffset: 2,
                font: .pixelSystem(size: 11, weight: .semibold)
            ))
        } else if authManager.isGuestMode {
            Button(action: { authManager.isGuestMode = false }) {
                Text(uiLanguage == .vi ? "Đăng nhập" : "Sign in")
            }
            .buttonStyle(PixelButtonStyle(
                fill: character.color,
                foreground: .white,
                paddingH: 14, paddingV: 7, blockSize: 2, steps: 2,
                borderWidth: 2, shadowOffset: 2,
                font: .pixelSystem(size: 11, weight: .semibold)
            ))
        }
    }

    private func accountLabel(for user: User) -> String {
        let who: String
        if let email = user.email, !email.isEmpty { who = email }
        else if let name = user.displayName, !name.isEmpty { who = name }
        else { who = uiLanguage == .vi ? "Đã đăng nhập" : "Signed in" }
        switch authManager.authMethod {
        case "google": return "\(who) · Google"
        case "email":  return who
        case "pin":    return "\(who) · PIN"
        default:       return who
        }
    }
}

// MARK: - Progress Bento
//
// The colorful stat cards, relocated to a full-width band at the bottom of the
// profile (was crammed into the hero). Large Level/XP card + Streak card with a
// 7-day strip + small Lessons/Coins cards.

struct ProfileStatsBento: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var challengeProgress: ChallengeProgress
    @Environment(\.uiLanguage) private var uiLanguage

    /// Agentic-coding exercises completed / available (the active learning loop).
    private var completedExercises: Int {
        challengeProgress.activeChallenges.filter {
            challengeProgress.completedChallengeIds.contains($0.id)
        }.count
    }
    private var totalExercises: Int { challengeProgress.activeChallenges.count }

    // Measured width of the section, used to split the top row ~60/40.
    @State private var rowWidth: CGFloat = 0
    private let spacing: CGFloat = 10
    private let calendarFraction: CGFloat = 0.40
    /// Height of the top row (Level + Calendar).
    private let cardRowHeight: CGFloat = 270
    /// Height of the bottom row (Lessons + Coins) — a little shorter.
    private let statRowHeight: CGFloat = 200

    // XP-within-current-level math (mirrors XPProgressView5).
    private var xpPrev: Int { (appState.userLevel - 1) * 100 }
    private var xpInLevel: Int { appState.totalXP - xpPrev }
    private var xpNeeded: Int { (appState.userLevel * 100) - xpPrev }
    private var xpPct: Double { min(1.0, Double(xpInLevel) / Double(max(1, xpNeeded))) }

    private var calendarWidth: CGFloat { max(0, (rowWidth - spacing) * calendarFraction) }
    private var levelWidth: CGFloat { max(0, (rowWidth - spacing) * (1 - calendarFraction)) }

    /// The dashboard tracks real data — the user's actual saved daily snapshots.
    /// Both the calendar and the momentum sparkline read from this.
    private var calendarSnapshots: [DailySnapshot] {
        appState.dailySnapshots
    }

    /// Total lessons available (one per skill across the tiers) — denominator
    /// for the Lessons progress bar.
    private var totalLessons: Int {
        GameData.skillTiers.flatMap { $0.skills }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiLanguage == .vi ? "Tiến độ của bạn" : "Your progress")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            // Top row: Level/XP card (~60%) next to the streak calendar (~40%).
            // This row absorbs the spare vertical space — both cards grow.
            HStack(alignment: .top, spacing: spacing) {
                ProfileLevelCard(
                    level: appState.userLevel,
                    xpInLevel: xpInLevel,
                    xpNeeded: xpNeeded,
                    pct: xpPct,
                    snapshots: calendarSnapshots
                )
                .frame(width: levelWidth)
                .frame(maxHeight: .infinity)

                ProfileStreakCalendar(streak: appState.streak,
                                      best: appState.longestStreak,
                                      snapshots: calendarSnapshots)
                    .frame(width: calendarWidth)
                    .frame(maxHeight: .infinity)
            }
            // Compact fixed height so the progress cards sit close to the stat
            // cards' height instead of towering over them.
            .frame(height: cardRowHeight)

            // Bottom row: Lessons + Coins. Matched to the top row's height so
            // all four cards form a uniform 2×2 grid — each carries supporting
            // content (lesson progress, coin context) so the height reads full.
            HStack(spacing: spacing) {
                ProfileStatChip(accent: CodepetTheme.accentTeal, icon: "book.fill",
                                value: "\(completedExercises)",
                                label: "Exercises", darkText: true,
                                progress: Double(completedExercises) / Double(max(1, totalExercises)),
                                footnote: "\(completedExercises) of \(totalExercises) completed",
                                badge: "\(appState.totalXP) XP")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ProfileStatChip(accent: CodepetTheme.accentGold, icon: "bitcoinsign.circle.fill",
                                value: "\(gameState.coins)",
                                label: "Coins", darkText: true,
                                footnote: "Earn from lessons, challenges & streaks. Spend on food, hearts & cosmetics.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: statRowHeight)
        }
        // Measure the section width (driven by the always-full-width bottom row)
        // so the top row can split ~60/40 without a layout feedback loop.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rowWidth = geo.size.width }
                    .onChange(of: geo.size.width) { newValue in rowWidth = newValue }
            }
        )
    }
}

/// The bento headline card: the XP ring (left) next to a **momentum** panel
/// (right) — this-week XP, week-over-week trend, and a 14-day XP sparkline —
/// so the card shows acceleration, not just a static level. Momentum is derived
/// from `snapshots` (per-day `totalXP` deltas).
private struct ProfileLevelCard: View {
    let level: Int
    let xpInLevel: Int
    let xpNeeded: Int
    let pct: Double
    let snapshots: [DailySnapshot]

    private let ink = Color.white
    private let accent = CodepetTheme.accentPurple

    // MARK: momentum math

    private var xpByDay: [Date: Int] {
        let cal = Calendar.current
        let sorted = snapshots.sorted { $0.date < $1.date }
        var prev = 0
        var map: [Date: Int] = [:]
        for snap in sorted {
            map[cal.startOfDay(for: snap.date)] = max(0, snap.totalXP - prev)
            prev = snap.totalXP
        }
        return map
    }

    /// XP gained per day for the last 14 days, oldest → newest.
    private var dailyGains: [Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let map = xpByDay
        return stride(from: 13, through: 0, by: -1).map { off in
            let day = cal.date(byAdding: .day, value: -off, to: today) ?? today
            return map[day] ?? 0
        }
    }

    private var thisWeek: Int { dailyGains.suffix(7).reduce(0, +) }
    private var lastWeek: Int { dailyGains.prefix(7).reduce(0, +) }

    private var weekDeltaPct: Int? {
        guard lastWeek > 0 else { return nil }
        return Int(((Double(thisWeek) - Double(lastWeek)) / Double(lastWeek)) * 100.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(ink.opacity(0.18)))
                Text("LEVEL")
                    .font(.pixelSystem(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(ink.opacity(0.85))
                Spacer()
            }

            HStack(alignment: .center, spacing: 24) {
                // Left: XP ring + "to next level" — centered in the card height.
                VStack(spacing: 8) {
                    ZStack {
                        Circle().stroke(ink.opacity(0.22), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: max(0.001, pct))
                            .stroke(ink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 1) {
                            Text("Lv \(level)")
                                .font(.pixelSystem(size: 26, weight: .heavy))
                                .foregroundColor(ink)
                            Text("\(xpInLevel)/\(xpNeeded)")
                                .font(.pixelSystem(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(ink.opacity(0.85))
                        }
                    }
                    .frame(width: 124, height: 124)

                    Text("\(max(0, xpNeeded - xpInLevel)) XP to Lv \(level + 1)")
                        .font(.pixelSystem(size: 11, weight: .semibold))
                        .foregroundColor(ink.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                // Right: momentum — fills the card's width and height so the
                // sparkline grows instead of leaving the bottom empty.
                momentumPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .pixelBox(fill: accent, shadowOffset: 3, blockSize: 3, steps: 2, borderWidth: 3)
    }

    @ViewBuilder
    private var momentumPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("+\(thisWeek)")
                    .font(.pixelSystem(size: 28, weight: .heavy))
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("XP this week")
                    .font(.pixelSystem(size: 12, weight: .semibold))
                    .foregroundColor(ink.opacity(0.85))

                Spacer(minLength: 0)

                if let pct = weekDeltaPct {
                    HStack(spacing: 3) {
                        Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(abs(pct))%")
                            .font(.pixelSystem(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ink.opacity(0.18)))
                }
            }

            XPSparkline(values: dailyGains, ink: ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("vs last week · last 14 days")
                .font(.pixelSystem(size: 10, weight: .medium))
                .foregroundColor(ink.opacity(0.7))
        }
    }
}

/// A compact bar sparkline for daily XP. Zero-days render as a faint stub so the
/// gaps read as "no activity" rather than disappearing.
private struct XPSparkline: View {
    let values: [Int]
    let ink: Color

    var body: some View {
        let maxV = max(1, values.max() ?? 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(values.indices, id: \.self) { i in
                    let v = values[i]
                    let h = v == 0 ? 3 : max(5, CGFloat(v) / CGFloat(maxV) * geo.size.height)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ink.opacity(v == 0 ? 0.22 : 0.9))
                        .frame(height: h)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// The streak rendered as a real, browsable **month calendar** (the shape every
/// reference dashboard uses): a flame/streak header with month navigation, a
/// weekday row, and a grid of dated cells. Days you were active are filled in
/// brand orange (deeper = more XP that day); today is ringed; adjacent-month
/// days are dimmed. Driven by `dailySnapshots` (90-day retention).
private struct ProfileStreakCalendar: View {
    let streak: Int
    let best: Int
    let snapshots: [DailySnapshot]

    /// 0 = current month, −1 = last month, … Clamped so you can page back
    /// through the retained window but never into the future.
    @State private var monthOffset = 0

    private let accent = CodepetTheme.accentOrange
    private let darkInk = Color(hex: "#2D2B26")
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    // startOfDay → XP earned that day (gain vs. the previous recorded day).
    private var xpByDay: [Date: Int] {
        let cal = Calendar.current
        let sorted = snapshots.sorted { $0.date < $1.date }
        var prev = 0
        var map: [Date: Int] = [:]
        for snap in sorted {
            map[cal.startOfDay(for: snap.date)] = max(0, snap.totalXP - prev)
            prev = snap.totalXP
        }
        return map
    }

    private var activeDays: Set<Date> {
        let cal = Calendar.current
        return Set(snapshots.map { cal.startOfDay(for: $0.date) })
    }

    private var displayedMonth: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .month, value: monthOffset, to: today) ?? today
    }

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let active = activeDays
        let xp = xpByDay
        let cells = monthGrid(for: displayedMonth, calendar: cal)
        let monthActiveCount = cells.filter { $0.inMonth && active.contains($0.date) }.count

        // Orange card with dark ink (far more legible on this orange than white).
        // At ~40% width the side stats rail no longer fits, so the streak
        // headline + numbers fold into a compact header above the month grid.
        let weekRows = stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0 ..< min($0 + 7, cells.count)])
        }

        VStack(alignment: .leading, spacing: 8) {
            header(monthActiveCount: monthActiveCount)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.pixelSystem(size: 11, weight: .bold))
                        .foregroundColor(darkInk.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }

            // Equal-height week rows so the grid fills the card height evenly.
            VStack(spacing: 3) {
                ForEach(weekRows.indices, id: \.self) { r in
                    HStack(spacing: 4) {
                        ForEach(weekRows[r]) { cell in
                            dayCell(cell, today: today, active: active, xp: xp)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pixelBox(fill: accent, shadowOffset: 3, blockSize: 3, steps: 2, borderWidth: 3)
    }

    // MARK: header (flame streak + numbers + month nav)

    @ViewBuilder
    private func header(monthActiveCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Flame chip: white disc, orange flame.
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white))

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(streak)")
                        .font(.pixelSystem(size: 18, weight: .heavy))
                        .foregroundColor(darkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("DAY STREAK")
                        .font(.pixelSystem(size: 9, weight: .semibold))
                        .tracking(0.4)
                        .foregroundColor(darkInk.opacity(0.65))
                }

                Spacer(minLength: 6)

                navButton(systemName: "chevron.left", enabled: monthOffset > -11) {
                    if monthOffset > -11 { monthOffset -= 1 }
                }
                Text(Self.monthFormatter.string(from: displayedMonth))
                    .font(.pixelSystem(size: 13, weight: .bold))
                    .foregroundColor(darkInk)
                    .fixedSize()
                navButton(systemName: "chevron.right", enabled: monthOffset < 0) {
                    if monthOffset < 0 { monthOffset += 1 }
                }
            }

            Text(best > 0 ? "best \(best) · \(monthActiveCount) active this month"
                          : "\(monthActiveCount) active this month")
                .font(.pixelSystem(size: 9, weight: .medium))
                .foregroundColor(darkInk.opacity(0.7))
        }
    }

    @ViewBuilder
    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(enabled ? darkInk : darkInk.opacity(0.3))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(enabled ? 0.9 : 0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: day cell

    @ViewBuilder
    private func dayCell(_ cell: DayCell, today: Date, active: Set<Date>, xp: [Date: Int]) -> some View {
        let isToday = cell.date == today
        let isActive = cell.inMonth && active.contains(cell.date)
        let level = isActive ? intensity(xp[cell.date] ?? 0) : 0
        let dayNum = Calendar.current.component(.day, from: cell.date)

        ZStack {
            // White discs carry the dark number; today is a solid white disc
            // marked with a dark ring so it reads as "selected" vs. a busy day.
            if isToday {
                Circle().fill(.white)
                Circle().strokeBorder(darkInk, lineWidth: 1.5)
            } else if isActive {
                Circle().fill(Color.white.opacity(fillOpacity(level)))
            }

            Text("\(dayNum)")
                .font(.pixelSystem(size: 13, weight: isToday ? .bold : .semibold))
                .foregroundColor(cell.inMonth ? darkInk : darkInk.opacity(0.28))
        }
        .frame(width: 26, height: 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: helpers

    private func intensity(_ earned: Int) -> Int {
        switch earned {
        case 0:        return 1   // showed up
        case 1..<50:   return 2
        case 50..<150: return 3
        default:       return 4
        }
    }

    private func fillOpacity(_ level: Int) -> Double {
        switch level {
        case 1:  return 0.35
        case 2:  return 0.55
        case 3:  return 0.78
        default: return 1.0
        }
    }

    // MARK: month grid construction

    private struct DayCell: Identifiable {
        let id = UUID()
        let date: Date
        let inMonth: Bool
    }

    /// Builds the calendar grid for `monthDate`: leading days from the previous
    /// month to pad the first week (Sun-start), the month's own days, then
    /// trailing days to complete the final week.
    private func monthGrid(for monthDate: Date, calendar cal: Calendar) -> [DayCell] {
        let comps = cal.dateComponents([.year, .month], from: monthDate)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        let daysInMonth = range.count
        let leading = cal.component(.weekday, from: firstOfMonth) - 1   // 0 = Sun start
        let total = leading + daysInMonth
        let weeks = Int(ceil(Double(total) / 7.0))
        let gridStart = cal.date(byAdding: .day, value: -leading, to: firstOfMonth)!

        return (0..<(weeks * 7)).map { i in
            let date = cal.date(byAdding: .day, value: i, to: gridStart)!
            let inMonth = cal.isDate(date, equalTo: firstOfMonth, toGranularity: .month)
            return DayCell(date: cal.startOfDay(for: date), inMonth: inMonth)
        }
    }
}

/// One brand-colored stat chip for the hero strip. Content is anchored LEFT —
/// icon chip, then a big value over a small uppercase label — so the number
/// carries the tile instead of floating in centered dead space.
private struct ProfileStatChip: View {
    let accent: Color
    let icon: String
    let value: String
    let label: String
    var darkText: Bool = false
    /// Optional 0…1 progress bar (e.g. lessons completed / total).
    var progress: Double? = nil
    /// Caption under the bar / at the bottom of the card.
    var footnote: String? = nil
    /// Optional trailing badge (e.g. XP earned), shown top-right of the header.
    var badge: String? = nil

    private var ink: Color { darkText ? Color(hex: "#2D2B26") : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: icon + big value + label
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ink)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(ink.opacity(0.18)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.pixelSystem(size: 28, weight: .heavy))
                        .foregroundColor(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(label.uppercased())
                        .font(.pixelSystem(size: 11, weight: .semibold))
                        .foregroundColor(ink.opacity(0.85))
                        .tracking(0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)

                if let badge = badge {
                    Text(badge)
                        .font(.pixelSystem(size: 12, weight: .bold))
                        .foregroundColor(ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ink.opacity(0.18)))
                }
            }

            Spacer(minLength: 0)

            // Footer: optional progress bar + caption, so a tall card reads full.
            if let progress = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ink.opacity(0.2))
                        Capsule()
                            .fill(ink)
                            .frame(width: max(8, geo.size.width * min(1, max(0, progress))))
                    }
                }
                .frame(height: 8)
            }

            if let footnote = footnote {
                Text(footnote)
                    .font(.pixelSystem(size: 11, weight: .medium))
                    .foregroundColor(ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pixelBox(fill: accent, shadowOffset: 3, blockSize: 3, steps: 2, borderWidth: 3)
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

    // Adaptive so all companions sit in one tidy row on wide windows and wrap
    // gracefully on narrow ones — a compact switcher, not a showcase.
    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiLanguage == .vi ? "Pet của bạn" : "Your Pet")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(alignment: .leading, spacing: 10) {
                Text(uiLanguage == .vi
                     ? "Đổi pet bất cứ lúc nào. Tiến độ vẫn được giữ."
                     : "Switch companions any time. Progress stays.")
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: columns, spacing: 8) {
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
            .padding(14)
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
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(character.color.opacity(isSelected ? 0.22 : (isHovered ? 0.14 : 0.07)))
                        .frame(height: 50)

                    CharacterImage(character.id, size: 38)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? character.color : Color.clear, lineWidth: 2)
                )

                Text(character.name)
                    .font(.pixelSystem(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? character.color : Color(hex: "#2D2B26"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preferences (merged: app voice + display language)
//
// Both are rarely-changed "how the app talks/shows" settings, so they share one
// compact card instead of two full sections: App voice as a dropdown, Display
// language as a small segmented control.

struct PreferencesSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.uiLanguage) private var uiLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiLanguage == .vi ? "Tùy chỉnh" : "Preferences")
                .font(.pixelSystem(size: 14, weight: .semibold, design: .default))

            VStack(spacing: 12) {
                // App voice — dropdown
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(uiLanguage == .vi ? "Giọng điệu" : "App voice")
                            .font(.pixelSystem(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#2D2B26"))
                        Text(appState.languagePersona.blurb)
                            .font(.pixelSystem(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    Menu {
                        ForEach(LanguagePersona.allCases, id: \.self) { persona in
                            Button {
                                appState.languagePersona = persona
                            } label: {
                                if appState.languagePersona == persona {
                                    Label("\(persona.icon)  \(persona.displayName)", systemImage: "checkmark")
                                } else {
                                    Text("\(persona.icon)  \(persona.displayName)")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(appState.languagePersona.icon)
                                .font(.pixelSystem(size: 13))
                            Text(appState.languagePersona.displayName)
                                .font(.pixelSystem(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .pixelBox(fill: Color(hex: "#F7F5FC"),
                                  shadowOffset: 2, blockSize: 2, steps: 2, borderWidth: 2)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Rectangle()
                    .fill(Color(hex: "#E0DBEF"))
                    .frame(height: 1)

                // Display language — segmented
                HStack(alignment: .center, spacing: 10) {
                    Text(uiLanguage == .vi ? "Ngôn ngữ hiển thị" : "Display language")
                        .font(.pixelSystem(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D2B26"))

                    Spacer(minLength: 8)

                    Picker("", selection: $appState.uiLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text("\(lang.flag)  \(lang.displayName)").tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

            }
            .padding(14)
            .pixelBox(fill: Color.white)
        }
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

            VStack(alignment: .leading, spacing: 10) {
                // Three compact chips in a row…
                HStack(spacing: 8) {
                    ForEach(LanguagePersona.allCases, id: \.self) { persona in
                        PersonaChip(
                            persona: persona,
                            isSelected: appState.languagePersona == persona,
                            action: { appState.languagePersona = persona }
                        )
                    }
                }

                // …and a single caption explaining the active choice, so the
                // per-option blurbs don't each take a full row.
                Text(appState.languagePersona.blurb)
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .pixelBox(fill: Color.white)
        }
    }
}

private struct PersonaChip: View {
    let persona: LanguagePersona
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    private let accent = Color(hex: "#7B6BD8")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(persona.icon)
                    .font(.pixelSystem(size: 15))
                Text(persona.displayName)
                    .font(.pixelSystem(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? accent : Color(hex: "#2D2B26"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.pixelSystem(size: 10, weight: .bold))
                        .foregroundColor(accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? accent.opacity(0.10)
                          : (isHovered ? Color(hex: "#F7F5FC") : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accent : Color(hex: "#E0DBEF"),
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

    private var helpText: String {
        uiLanguage == .vi
            ? "Thay tab Reflection bằng demo 13 phút có sẵn. ⌥1..⌥4 bắn milestone, ⌥5 hiện reflection, ⌥6..⌥8 health nudge, ⌥9 demo Tips, ⌥0 nhảy thẳng tới summary."
            : "Replaces Reflection tab with hardcoded 13-min demo. ⌥1..⌥4 milestones, ⌥5 reflection, ⌥6..⌥8 health nudge, ⌥9 Tips demo, ⌥0 panic-skip."
    }

    var body: some View {
        // Dev-only — kept to a single slim row. The shortcut blurb lives in a
        // hover tooltip instead of taking a whole paragraph on the profile.
        HStack(spacing: 10) {
            Text(uiLanguage == .vi ? "GỠ LỖI" : "DEBUG")
                .font(.pixelSystem(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundColor(.secondary)

            Toggle(isOn: $appState.demoModeEnabled) {
                Text(uiLanguage == .vi ? "Chế độ Demo" : "Demo Mode")
                    .font(.pixelSystem(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#2D2B26"))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .fixedSize()

            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .help(helpText)
        }
        .fixedSize()
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .pixelBox(fill: Color.white)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
