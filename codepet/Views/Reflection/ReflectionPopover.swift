import SwiftUI

/// Compact reflection block for the menu bar popover.
/// Stacked below the existing pet stats in `MenuBarView`.
struct ReflectionSummaryBlock: View {
    @EnvironmentObject var appState: AppState

    private var day: ReflectionDay { ReflectionMockData.day(for: .today) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Eyebrow(text: "Today so far")
                Spacer()
                Circle()
                    .fill(ReflectionTheme.color(for: day.mood))
                    .frame(width: 6, height: 6)
                Text(day.mood.label)
                    .font(ReflectionTheme.sans(10, weight: .medium))
                    .foregroundColor(ReflectionTheme.color(for: day.mood))
            }

            HStack(alignment: .top, spacing: 16) {
                popoverStat(number: day.captured, label: "Captured", accent: false)
                popoverStat(number: day.decisions, label: "Decisions", accent: false)
                popoverStat(number: day.risks, label: "Risks", accent: day.risks > 0)
            }

            Button {
                appState.selectedTab = .reflection
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Text("Open full reflection")
                        .font(ReflectionTheme.sans(12, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ReflectionTheme.accent)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func popoverStat(number: Int, label: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(number)")
                .font(ReflectionTheme.serif(28, weight: .regular))
                .foregroundColor(accent ? ReflectionTheme.accent : ReflectionTheme.primaryText)
            Text(label)
                .font(ReflectionTheme.sans(10, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(ReflectionTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ReflectionSummaryBlock()
        .environmentObject(AppState())
        .padding(12)
        .frame(width: 260)
}
