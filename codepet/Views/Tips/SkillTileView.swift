import SwiftUI

/// A single skill tile in the Tips grid. Reads live progress from TipsState.
struct SkillTileView: View {
    @EnvironmentObject var tipsState: TipsState
    @Environment(\.uiLanguage) private var uiLanguage

    let petId: String
    let index: Int
    let tile: TipSkillTile

    private var progress: SkillProgress {
        tipsState.progress(for: petId, index: index)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: tile.icon)
                    .font(.pixelSystem(size: 16, weight: .medium))
                    .foregroundColor(progress.isMastered ? ReflectionTheme.brandGreen : ReflectionTheme.accent)
                Spacer()

                if progress.isMastered {
                    Text(uiLanguage == .vi ? "Thành thạo" : "Mastered")
                        .font(ReflectionTheme.sans(10, weight: .semibold))
                        .foregroundColor(ReflectionTheme.brandGreen)
                } else {
                    Text("\(progress.practiceCount)/5")
                        .font(ReflectionTheme.mono(10))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
            }

            Text(tile.title(uiLanguage))
                .font(ReflectionTheme.serif(15, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(tile.hint(uiLanguage))
                .font(ReflectionTheme.sans(11))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            // Progress dots
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { dotIndex in
                    Circle()
                        .fill(dotIndex < progress.practiceCount
                              ? (progress.isMastered ? ReflectionTheme.brandGreen : ReflectionTheme.accent)
                              : ReflectionTheme.borderLight)
                        .frame(width: 6, height: 6)
                }
            }

            // Practice button (only if not mastered)
            if !progress.isMastered {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tipsState.recordPractice(for: petId, index: index)
                    }
                }) {
                    Text(uiLanguage == .vi ? "Đánh dấu luyện tập" : "Mark practiced")
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(PixelButtonStyle(
                    fill: ReflectionTheme.accent.opacity(0.10),
                    foreground: ReflectionTheme.accent,
                    paddingH: 10,
                    paddingV: 4,
                    blockSize: 2,
                    steps: 2,
                    borderWidth: 1,
                    shadowOffset: 1,
                    font: .pixelSystem(size: 10, weight: .semibold)
                ))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .pixelBox(fill: ReflectionTheme.cardBackground)
    }
}
