import SwiftUI

// MARK: - Pixel Art Icon Shapes

/// A small pixel-art trophy drawn with rectangles
struct PixelTrophy: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let p = size / 9
        Canvas { ctx, _ in
            // Cup top rim
            ctx.fill(Path(CGRect(x: p, y: 0, width: p * 7, height: p)), with: .color(color))
            // Cup body
            ctx.fill(Path(CGRect(x: p, y: p, width: p * 7, height: p * 3)), with: .color(color))
            // Handles
            ctx.fill(Path(CGRect(x: 0, y: p, width: p, height: p * 2)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 8, y: p, width: p, height: p * 2)), with: .color(color))
            // Taper
            ctx.fill(Path(CGRect(x: p * 2, y: p * 4, width: p * 5, height: p)), with: .color(color))
            // Stem
            ctx.fill(Path(CGRect(x: p * 3, y: p * 5, width: p * 3, height: p * 2)), with: .color(color))
            // Base
            ctx.fill(Path(CGRect(x: p * 2, y: p * 7, width: p * 5, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p * 8, width: p * 7, height: p)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// A small pixel-art star
struct PixelStar: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let p = size / 9
        Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: p * 4, y: 0, width: p, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 3, y: p, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 2, width: p * 5, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: p * 3, width: p * 9, height: p * 2)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p * 5, width: p * 7, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 6, width: p * 5, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p * 7, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 5, y: p * 7, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: p * 8, width: p * 2, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 7, y: p * 8, width: p * 2, height: p)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// A pixel-art flame
struct PixelFlame: View {
    let color: Color
    let tipColor: Color
    let size: CGFloat

    var body: some View {
        let p = size / 9
        Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: p * 4, y: 0, width: p, height: p)), with: .color(tipColor))
            ctx.fill(Path(CGRect(x: p * 3, y: p, width: p * 3, height: p)), with: .color(tipColor))
            ctx.fill(Path(CGRect(x: p * 3, y: p * 2, width: p * 4, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 3, width: p * 5, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 4, width: p * 6, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p * 5, width: p * 7, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p * 6, width: p * 7, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 7, width: p * 5, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 3, y: p * 8, width: p * 3, height: p)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// A pixel-art lightning bolt
struct PixelBolt: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let p = size / 9
        Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: p * 4, y: 0, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 3, y: p, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 2, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p * 3, width: p * 6, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 3, y: p * 4, width: p * 5, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 4, y: p * 5, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 3, y: p * 6, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 7, width: p * 3, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 8, width: p * 2, height: p)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// A pixel-art book
struct PixelBook: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let p = size / 9
        Canvas { ctx, _ in
            let spine = color.opacity(0.7)
            ctx.fill(Path(CGRect(x: p, y: 0, width: p * 7, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: p, width: p * 8, height: p * 6)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: p, width: p, height: p * 6)), with: .color(spine))
            ctx.fill(Path(CGRect(x: p, y: p * 7, width: p * 7, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: p * 8, width: p * 8, height: p)), with: .color(spine))
        }
        .frame(width: size, height: size)
    }
}

/// A pixel-art crosshair/target
struct PixelTarget: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let p = size / 9
        Canvas { ctx, _ in
            // Outer ring
            ctx.fill(Path(CGRect(x: p * 2, y: 0, width: p * 5, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p, width: p * 2, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 6, y: p, width: p * 2, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: p * 2, width: p, height: p * 5)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 8, y: p * 2, width: p, height: p * 5)), with: .color(color))
            ctx.fill(Path(CGRect(x: p, y: p * 7, width: p * 2, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 6, y: p * 7, width: p * 2, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 8, width: p * 5, height: p)), with: .color(color))
            // Center dot
            ctx.fill(Path(CGRect(x: p * 4, y: p * 4, width: p, height: p)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

/// A pixel-art map/scroll icon
struct PixelMap: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        let p = size / 9
        Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: p, y: 0, width: p * 7, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: 0, y: p, width: p * 9, height: p * 6)), with: .color(color))
            // Path line
            ctx.fill(Path(CGRect(x: p * 2, y: p * 3, width: p, height: p)), with: .color(.white.opacity(0.5)))
            ctx.fill(Path(CGRect(x: p * 3, y: p * 4, width: p * 2, height: p)), with: .color(.white.opacity(0.5)))
            ctx.fill(Path(CGRect(x: p * 5, y: p * 3, width: p, height: p)), with: .color(.white.opacity(0.5)))
            ctx.fill(Path(CGRect(x: p * 6, y: p * 2, width: p, height: p)), with: .color(.white.opacity(0.5)))
            ctx.fill(Path(CGRect(x: p, y: p * 7, width: p * 7, height: p)), with: .color(color))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 8, width: p * 5, height: p)), with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pixel Card Border Modifier

struct PixelCardStyle: ViewModifier {
    var borderColor: Color = Color(hex: "#E0DBEF")

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Shadow layer (pixel offset)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#2D2B3E").opacity(0.06))
                        .offset(x: 2, y: 2)
                    // Card face
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#F7F5FC"))
                    // Pixel border
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(borderColor, lineWidth: 1.5)
                }
            )
    }
}

extension View {
    func pixelCard(borderColor: Color = Color(hex: "#E0DBEF")) -> some View {
        modifier(PixelCardStyle(borderColor: borderColor))
    }
}

// MARK: - Color Palette for mixed icons
struct InsightColors {
    static let orange = Color(hex: "#F0922B")
    static let gold = Color(hex: "#ECBA2A")
    static let green = Color(hex: "#5EC26A")
    static let red = Color(hex: "#E06050")
    static let blue = Color(hex: "#4A9FE5")
    static let purple = Color(hex: "#8B7BE8")
    static let teal = Color(hex: "#3DC0B0")
    static let pink = Color(hex: "#E07BAD")
}

// MARK: - Main View

struct InsightsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("◆ CODEPET")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#8B7BE8"))
                    Text("Your Progress")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B3E"))
                    Text("Track your learning journey — one pixel at a time.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#2D2B3E").opacity(0.55))
                }

                // Weekly Stats
                PixelWeeklyStats()

                // Streak Calendar
                PixelStreakCalendar()

                // Statistics Grid
                PixelStatisticsGrid()

                // Activity Breakdown
                PixelActivityBreakdown()
            }
            .padding(24)
        }
        .background(Color(hex: "#F0EDF8"))
    }
}

// MARK: - Weekly Stats (Pixel Style)

struct PixelWeeklyStats: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS WEEK")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E").opacity(0.4))

            HStack(spacing: 12) {
                PixelStatChip(
                    icon: { PixelTarget(color: InsightColors.blue, size: 20) },
                    value: "\(appState.completedChallenges.count)",
                    label: "Challenges",
                    accentColor: InsightColors.blue
                )

                PixelStatChip(
                    icon: { PixelBook(color: InsightColors.green, size: 20) },
                    value: "\(appState.completedLessons.count)",
                    label: "Skills",
                    accentColor: InsightColors.green
                )

                PixelStatChip(
                    icon: { PixelStar(color: InsightColors.gold, size: 20) },
                    value: "\(appState.totalXP)",
                    label: "XP Earned",
                    accentColor: InsightColors.gold
                )
            }
        }
    }
}

struct PixelStatChip<Icon: View>: View {
    let icon: () -> Icon
    let value: String
    let label: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            icon()

            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E"))

            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E").opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .pixelCard(borderColor: accentColor.opacity(0.3))
    }
}

// MARK: - Streak Calendar (Pixel Style)

struct PixelStreakCalendar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STREAK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B3E").opacity(0.4))

                Spacer()

                HStack(spacing: 6) {
                    PixelFlame(color: InsightColors.orange, tipColor: InsightColors.gold, size: 14)
                    Text("\(appState.streak)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(InsightColors.orange)
                    Text("days")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#2D2B3E").opacity(0.4))
                }
            }

            // 7-day grid
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let dayOffset = 6 - index
                    let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
                    let dayNum = Calendar.current.component(.day, from: date)
                    let dayName = shortDayName(for: date)
                    let isActive = index >= (7 - min(appState.streak, 7))
                    let isToday = dayOffset == 0

                    VStack(spacing: 4) {
                        Text(dayName)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(isToday ? InsightColors.orange : Color(hex: "#2D2B3E").opacity(0.35))

                        ZStack {
                            // Circle shape
                            Circle()
                                .fill(isActive ? streakColor(for: index) : Color(hex: "#E0DBEF"))
                                .frame(width: 34, height: 34)
                            Circle()
                                .stroke(isActive ? streakColor(for: index).opacity(0.6) : Color(hex: "#D0C9E2"), lineWidth: 1)
                                .frame(width: 34, height: 34)

                            if isActive {
                                // Pixel checkmark
                                PixelCheck(size: 12)
                            } else {
                                Text("\(dayNum)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "#2D2B3E").opacity(0.3))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .pixelCard(borderColor: InsightColors.orange.opacity(0.25))
        }
    }

    private func streakColor(for index: Int) -> Color {
        let colors: [Color] = [
            InsightColors.gold.opacity(0.7),
            InsightColors.gold.opacity(0.8),
            InsightColors.orange.opacity(0.7),
            InsightColors.orange.opacity(0.8),
            InsightColors.orange.opacity(0.9),
            InsightColors.orange,
            InsightColors.red
        ]
        return colors[min(index, colors.count - 1)]
    }

    private func shortDayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(2)).uppercased()
    }
}

/// Tiny pixel checkmark
struct PixelCheck: View {
    let size: CGFloat

    var body: some View {
        let p = size / 7
        Canvas { ctx, _ in
            let w = Color.white
            ctx.fill(Path(CGRect(x: p, y: p * 4, width: p, height: p)), with: .color(w))
            ctx.fill(Path(CGRect(x: p * 2, y: p * 5, width: p, height: p)), with: .color(w))
            ctx.fill(Path(CGRect(x: p * 3, y: p * 4, width: p, height: p)), with: .color(w))
            ctx.fill(Path(CGRect(x: p * 4, y: p * 3, width: p, height: p)), with: .color(w))
            ctx.fill(Path(CGRect(x: p * 5, y: p * 2, width: p, height: p)), with: .color(w))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Statistics Grid (Pixel Style)

struct PixelStatisticsGrid: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATISTICS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E").opacity(0.4))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                PixelStatBox(
                    icon: { PixelTrophy(color: InsightColors.green, size: 22) },
                    title: "LEVEL",
                    value: "\(appState.userLevel)",
                    accent: InsightColors.green
                )
                PixelStatBox(
                    icon: { PixelStar(color: InsightColors.gold, size: 22) },
                    title: "TOTAL XP",
                    value: "\(appState.totalXP)",
                    accent: InsightColors.gold
                )
                PixelStatBox(
                    icon: { PixelBook(color: InsightColors.purple, size: 22) },
                    title: "LESSONS",
                    value: "\(appState.completedLessons.count)",
                    accent: InsightColors.purple
                )
                PixelStatBox(
                    icon: { PixelTarget(color: InsightColors.blue, size: 22) },
                    title: "CHALLENGES",
                    value: "\(appState.completedChallenges.count)",
                    accent: InsightColors.blue
                )
                PixelStatBox(
                    icon: { PixelFlame(color: InsightColors.orange, tipColor: InsightColors.gold, size: 22) },
                    title: "STREAK",
                    value: "\(appState.streak)",
                    accent: InsightColors.orange
                )
                PixelStatBox(
                    icon: { PixelMap(color: InsightColors.teal, size: 22) },
                    title: "TIER",
                    value: "\(appState.currentTier)",
                    accent: InsightColors.teal
                )
            }
        }
    }
}

struct PixelStatBox<Icon: View>: View {
    let icon: () -> Icon
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            icon()

            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E"))

            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E").opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .pixelCard(borderColor: accent.opacity(0.25))
    }
}

// MARK: - Activity Breakdown (Pixel Style)

struct PixelActivityBreakdown: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVITY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E").opacity(0.4))

            VStack(spacing: 0) {
                PixelActivityRow(
                    icon: { PixelBook(color: InsightColors.purple, size: 14) },
                    label: "Skills completed",
                    value: appState.completedLessons.count,
                    maxValue: 16,
                    barColor: InsightColors.purple
                )

                PixelDivider()

                PixelActivityRow(
                    icon: { PixelTarget(color: InsightColors.blue, size: 14) },
                    label: "Challenges done",
                    value: appState.completedChallenges.count,
                    maxValue: 16,
                    barColor: InsightColors.blue
                )

                PixelDivider()

                PixelActivityRow(
                    icon: { PixelMap(color: InsightColors.teal, size: 14) },
                    label: "Current tier",
                    value: appState.currentTier,
                    maxValue: 4,
                    barColor: InsightColors.teal
                )
            }
            .padding(14)
            .pixelCard()
        }
    }
}

struct PixelDivider: View {
    var body: some View {
        // Dashed pixel-style divider
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { _ in
                Rectangle()
                    .fill(Color(hex: "#E0DBEF"))
                    .frame(width: 4, height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

struct PixelActivityRow<Icon: View>: View {
    let icon: () -> Icon
    let label: String
    let value: Int
    let maxValue: Int
    let barColor: Color

    var body: some View {
        HStack(spacing: 10) {
            icon()
                .frame(width: 18, height: 18)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#2D2B3E"))

            Spacer()

            // Pixel progress bar
            PixelProgressBar(value: value, maxValue: maxValue, color: barColor)
                .frame(maxWidth: 90)

            Text("\(value)/\(maxValue)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B3E").opacity(0.45))
                .frame(width: 36, alignment: .trailing)
        }
    }
}

/// A segmented pixel progress bar
struct PixelProgressBar: View {
    let value: Int
    let maxValue: Int
    let color: Color

    private var segments: Int { min(maxValue, 10) }
    private var filledSegments: Int {
        guard maxValue > 0 else { return 0 }
        return Int(round(Double(value) / Double(maxValue) * Double(segments)))
    }

    var body: some View {
        GeometryReader { geo in
            let segWidth = (geo.size.width - CGFloat(segments - 1) * 2) / CGFloat(segments)
            HStack(spacing: 2) {
                ForEach(0..<segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < filledSegments ? color : Color(hex: "#E0DBEF"))
                        .frame(width: max(2, segWidth), height: 8)
                }
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#Preview {
    InsightsView()
        .environmentObject(AppState())
}
