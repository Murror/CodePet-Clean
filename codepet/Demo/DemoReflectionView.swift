import SwiftUI

/// The root view shown inside Reflection tab when `appState.demoModeEnabled`
/// is true. Reads everything from DemoScriptController — no JSONL polling,
/// no API calls. Layout mirrors ReflectionTab.body so the demo feels native.
struct DemoReflectionView: View {
    @EnvironmentObject var demo: DemoScriptController
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 280)

            Divider()
                .background(ReflectionTheme.borderLight)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    petHeader

                    if demo.sessionStartedAt == nil {
                        startPrompt
                    } else {
                        sessionBody
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .background(ReflectionTheme.background)
        .overlay(alignment: .topTrailing) {
            demoBadge.padding(12)
        }
        .animation(.easeOut(duration: 0.25), value: demo.firedMilestones)
        .animation(.easeOut(duration: 0.25), value: demo.reflectionRevealed)
    }

    // MARK: Pet header

    private var petHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            PetAvatar(mood: .calm, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(DemoScript.petName)
                    .font(ReflectionTheme.serif(18, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text(dateString(demo.sessionStartedAt ?? Date()))
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer()
            if demo.sessionStartedAt == nil {
                Button("Start session") { demo.startSession() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Start prompt

    private var startPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo Mode is on.")
                .font(ReflectionTheme.serif(20, weight: .medium))
            Text("Tap 'Start session', then press ⌥1 → ⌥4 to fire milestones, ⌥5 to reveal the reflection, ⌥0 to panic-skip.")
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Session body

    private var sessionBody: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(demo.firedMilestones) { milestone in
                DemoMilestoneCard(
                    milestone: milestone,
                    timestamp: timestamp(for: milestone)
                )
            }

            if demo.reflectionRevealed {
                reflectionCard
            } else if !demo.firedMilestones.isEmpty {
                reflectionPlaceholder
            }
        }
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💜 \(DemoScript.reflectionHeader)")
                .font(ReflectionTheme.serif(16, weight: .semibold))
                .foregroundColor(ReflectionTheme.primaryText)

            DemoTypewriterText(
                text: DemoScript.reflectionSummary,
                charactersPerSecond: 28,
                font: ReflectionTheme.sans(14),
                foregroundColor: ReflectionTheme.primaryText
            )

            Text(DemoScript.reflectionSignature)
                .font(ReflectionTheme.sans(13, weight: .medium))
                .foregroundColor(ReflectionTheme.accent)
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ReflectionTheme.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ReflectionTheme.accent.opacity(0.25), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var reflectionPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .foregroundColor(ReflectionTheme.mutedText)
            Text("Byte đang quan sát… (bấm ⌥5 để xem reflection)")
                .font(ReflectionTheme.sans(12))
                .foregroundColor(ReflectionTheme.mutedText)
        }
        .padding(.vertical, 6)
    }

    // MARK: Sidebar (event log)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Event log")
                    .font(ReflectionTheme.serif(16, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if demo.firedMilestones.isEmpty {
                        Text("No actions tracked yet.")
                            .font(ReflectionTheme.sans(11))
                            .foregroundColor(ReflectionTheme.mutedText)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(demo.firedMilestones) { milestone in
                            HStack(alignment: .top, spacing: 8) {
                                Text("[\(timeString(timestamp(for: milestone)))]")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(ReflectionTheme.mutedText)
                                Text(milestone.sidebarLabel)
                                    .font(ReflectionTheme.sans(11.5))
                                    .foregroundColor(ReflectionTheme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0xFD / 255.0, green: 0xFC / 255.0, blue: 0xF8 / 255.0))
    }

    // MARK: Badge

    private var demoBadge: some View {
        Text("DEMO MODE")
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.9))
            )
            .foregroundColor(.white)
    }

    // MARK: Helpers

    private func timestamp(for milestone: DemoScript.Milestone) -> Date {
        let base = demo.sessionStartedAt ?? Date()
        return base.addingTimeInterval(TimeInterval(milestone.offsetMinutesFromStart * 60))
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: date)
    }
}

#Preview {
    let demo = DemoScriptController()
    return DemoReflectionView()
        .environmentObject(demo)
        .environmentObject(AppState())
        .frame(width: 900, height: 800)
}
