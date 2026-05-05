import SwiftUI

struct TechnicalDetailsView: View {
    let prompt: String
    let events: [CapturedEvent]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                    Text("View technical details (\(events.count) actions)")
                        .font(ReflectionTheme.sans(11, weight: .medium))
                }
                .foregroundColor(ReflectionTheme.mutedText)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    promptRow
                    Divider().background(ReflectionTheme.borderLight)
                    ForEach(events) { event in
                        eventRow(event)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ReflectionTheme.cardBackground.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ReflectionTheme.borderLight, lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var promptRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PROMPT")
                .font(ReflectionTheme.mono(9, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(ReflectionTheme.mutedText)
            Text(prompt)
                .font(ReflectionTheme.mono(11))
                .foregroundColor(ReflectionTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func eventRow(_ event: CapturedEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.time)
                .font(ReflectionTheme.mono(10))
                .foregroundColor(ReflectionTheme.mutedText)
                .frame(width: 44, alignment: .leading)
            Text(event.text)
                .font(ReflectionTheme.mono(11))
                .foregroundColor(ReflectionTheme.secondaryText)
        }
    }
}
