import SwiftUI

/// Session-level summary spoken in the pet's single voice.
/// Same shape as a turn bubble: pet avatar + bubble — so the page reads as
/// one continuous narration from the pet, not a separate report card.
struct SessionSummaryView: View {
    @EnvironmentObject var appState: AppState
    let summary: SessionSummary?
    var onTriggerSummary: () -> Void = {}

    @State private var petFloat = false
    @State private var petGlow: CGFloat = 0

    private var pet: PetCharacter? {
        PetCharacter.all[appState.activeChar]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dividerLine

            HStack(alignment: .top, spacing: 12) {
                petAvatar(size: 44)
                Group {
                    if let summary = summary {
                        readyBubble(summary: summary)
                    } else {
                        loadingBubble
                    }
                }
            }
            .onAppear { startAnimations() }

            dividerLine
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            petFloat = true
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            petGlow = 1.0
        }
    }

    // MARK: - Ready state

    private func readyBubble(summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let pet = pet {
                    Text(pet.name)
                        .font(ReflectionTheme.sans(10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(ReflectionTheme.mutedText)
                    Text("·")
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Text("SESSION RECAP")
                    .font(ReflectionTheme.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(ReflectionTheme.accent)
            }

            Text(summary.summary)
                .font(ReflectionTheme.serif(14))
                .foregroundColor(ReflectionTheme.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if !summary.lesson.isEmpty {
                lessonRow(summary.lesson)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ReflectionTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ReflectionTheme.borderLight, lineWidth: 1)
        )
    }

    private func lessonRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.pixelSystem(size: 11, weight: .medium))
                .foregroundColor(ReflectionTheme.accent)
                .padding(.top, 3)
            Text(text)
                .font(ReflectionTheme.serif(13, weight: .medium))
                .italic()
                .foregroundColor(ReflectionTheme.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ReflectionTheme.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ReflectionTheme.accent.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Loading state

    private var loadingBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let pet = pet {
                    Text(pet.name)
                        .font(ReflectionTheme.sans(10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(ReflectionTheme.mutedText)
                    Text("·")
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Text("SESSION RECAP")
                    .font(ReflectionTheme.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(ReflectionTheme.mutedText)
            }

            skeletonLine(width: 0.9)
            skeletonLine(width: 0.75)
            skeletonLine(width: 0.55)

            Text("Mình đang sắp lại câu chuyện cho bạn…")
                .font(ReflectionTheme.sans(11))
                .italic()
                .foregroundColor(ReflectionTheme.mutedText)

            Button(action: onTriggerSummary) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.pixelSystem(size: 11, weight: .semibold))
                    Text("Summarize now")
                        .font(ReflectionTheme.sans(12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ReflectionTheme.accent)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ReflectionTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ReflectionTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Pet avatar (matches turn view)

    private func petAvatar(size: CGFloat) -> some View {
        ZStack {
            if let pet = pet {
                Circle()
                    .stroke(pet.color.opacity(0.35), lineWidth: 1.5)
                    .scaleEffect(1.0 + petGlow * 0.18)
                    .opacity(1.0 - petGlow * 0.7)
                    .frame(width: size, height: size)

                Image(pet.imageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(Circle().fill(pet.color.opacity(0.18)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(pet.color.opacity(0.55), lineWidth: 1.5))
                    .scaleEffect(petFloat ? 1.02 : 0.98)
                    .offset(y: petFloat ? -2 : 2)
                    .shadow(
                        color: pet.color.opacity(petFloat ? 0.45 : 0.3),
                        radius: petFloat ? 10 : 6,
                        x: 0,
                        y: petFloat ? 5 : 3
                    )
            } else {
                Circle()
                    .fill(ReflectionTheme.accent.opacity(0.2))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Helpers

    private var dividerLine: some View {
        Rectangle()
            .fill(ReflectionTheme.borderLight)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .padding(.vertical, 16)
    }

    private func skeletonLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(ReflectionTheme.borderLight.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 14)
            .scaleEffect(x: width, y: 1, anchor: .leading)
    }
}
