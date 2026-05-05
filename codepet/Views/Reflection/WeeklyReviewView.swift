import SwiftUI

// MOCKUP — Weekly Review ritual. No real function.
// Slight visual shift from ReflectionTab: warmer paper bg, more serif, generous whitespace.

struct WeeklyReviewView: View {
    var onClose: () -> Void = {}

    @State private var answerText: String = ""
    @State private var weekMarkedReviewed: Bool = false

    private let paperBg = Color(red: 0xFB / 255.0, green: 0xF8 / 255.0, blue: 0xF0 / 255.0)
    private let cardBg = Color(red: 0xFF / 255.0, green: 0xFD / 255.0, blue: 0xF7 / 255.0)

    private var day: ReflectionDay {
        ReflectionMockData.day(for: .thisWeek)
    }

    // Mock "last week" numbers for deltas
    private let lastWeekCaptured = 15
    private let lastWeekDecisions = 10
    private let lastWeekRisks = 4

    // Mock journal excerpts — responses user would've written during the week
    private struct JournalExcerpt {
        let date: String
        let captureRef: String
        let text: String
    }

    private let excerpts: [JournalExcerpt] = [
        JournalExcerpt(
            date: "Tue · Apr 18",
            captureRef: "10:42 · T1 Scope creep",
            text: "The filter request felt small but it's the fourth change this week. I said yes because the launch is still 3 days away — but now I'm not sure. Will cut tomorrow if no blocker."
        ),
        JournalExcerpt(
            date: "Thu · Apr 20",
            captureRef: "Fri 11:05 · T1 Scope creep",
            text: "Caught myself this time. Told the team no to the CSS rewrite. Still shipped the bug fix in 2 hours as originally scoped."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                headerBar
                chapterOne
                chapterTwo
                chapterThree
                chapterFour
                chapterFive
                chapterSix
                chapterSeven
                footer
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(paperBg)
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            PetAvatar(mood: .alert, size: 72)

            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "Weekly Review")
                Text("The week of Apr 16 – 22")
                    .font(ReflectionTheme.serif(18, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ReflectionTheme.secondaryText)
                    .padding(8)
                    .background(
                        Circle().fill(ReflectionTheme.borderLight.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Chapter 1 · One line

    private var chapterOne: some View {
        chapterContainer(number: 1, title: "One line") {
            Text("This week was scope creep-shaped.")
                .font(ReflectionTheme.serif(36, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
    }

    // MARK: - Chapter 2 · Numbers

    private var chapterTwo: some View {
        chapterContainer(number: 2, title: "Numbers") {
            HStack(alignment: .top, spacing: 40) {
                weekStat(number: day.captured, label: "Captured", delta: day.captured - lastWeekCaptured, accent: false)
                weekStat(number: day.decisions, label: "Decisions", delta: day.decisions - lastWeekDecisions, accent: false)
                weekStat(number: day.risks, label: "Risks", delta: day.risks - lastWeekRisks, accent: day.risks > 0)
            }
        }
    }

    private func weekStat(number: Int, label: String, delta: Int, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number)")
                .font(ReflectionTheme.serif(56, weight: .regular))
                .foregroundColor(accent ? ReflectionTheme.accent : ReflectionTheme.primaryText)

            Eyebrow(text: label)

            HStack(spacing: 4) {
                Image(systemName: delta > 0 ? "arrow.up" : delta < 0 ? "arrow.down" : "minus")
                    .font(.system(size: 9, weight: .semibold))
                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(ReflectionTheme.mono(11, weight: .medium))
                Text("vs last week")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            .foregroundColor(delta > 0 && accent ? ReflectionTheme.accent : ReflectionTheme.mutedText)
        }
    }

    // MARK: - Chapter 3 · What kept happening

    private struct PatternObservation {
        let pattern: PatternSummary
        let narrative: String
    }

    private var patternObservations: [PatternObservation] {
        [
            PatternObservation(
                pattern: day.patterns[0],
                narrative: "Five instances, across four features. The common thread isn't the features — it's that each addition was framed as trivial. You're being pulled toward a launch you can't yet see the edge of."
            ),
            PatternObservation(
                pattern: day.patterns[safe: 1] ?? day.patterns[0],
                narrative: "Three captures this week where validation was set aside for speed. Worth asking: which of these will you have to revisit in two weeks?"
            ),
            PatternObservation(
                pattern: day.patterns[safe: 2] ?? day.patterns[0],
                narrative: "Down by one versus last week. That's real. Keep noticing when the REST stack is already good enough."
            )
        ]
    }

    private var chapterThree: some View {
        chapterContainer(number: 3, title: "What kept happening") {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(Array(patternObservations.enumerated()), id: \.offset) { _, obs in
                    patternBlock(obs)
                }
            }
        }
    }

    private func patternBlock(_ obs: PatternObservation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(obs.pattern.triggerCode) · \(obs.pattern.label)")
                    .font(ReflectionTheme.sans(12, weight: .semibold))
                    .foregroundColor(ReflectionTheme.accent)
                Text("×\(obs.pattern.count)")
                    .font(ReflectionTheme.mono(11))
                    .foregroundColor(ReflectionTheme.mutedText)
                Spacer()
                Text(obs.pattern.deltaText)
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

            Text(obs.narrative)
                .font(ReflectionTheme.serif(17))
                .foregroundColor(ReflectionTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }

    // MARK: - Chapter 4 · Your own words

    private var chapterFour: some View {
        chapterContainer(number: 4, title: "Your own words") {
            if excerpts.isEmpty {
                Text("You didn't write anything this week. That's fine — some weeks are for doing.")
                    .font(ReflectionTheme.serif(16))
                    .italic()
                    .foregroundColor(ReflectionTheme.mutedText)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(excerpts.enumerated()), id: \.offset) { _, excerpt in
                        excerptBlock(excerpt)
                    }
                }
            }
        }
    }

    private func excerptBlock(_ excerpt: JournalExcerpt) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(ReflectionTheme.accent.opacity(0.5))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(excerpt.date)
                        .font(ReflectionTheme.sans(11, weight: .semibold))
                        .foregroundColor(ReflectionTheme.primaryText)
                    Text("·")
                        .foregroundColor(ReflectionTheme.mutedText)
                    Text(excerpt.captureRef)
                        .font(ReflectionTheme.mono(10))
                        .foregroundColor(ReflectionTheme.mutedText)
                }

                Text("“\(excerpt.text)”")
                    .font(ReflectionTheme.serif(15))
                    .italic()
                    .foregroundColor(ReflectionTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Chapter 5 · The week's capture

    private var curatedMoments: [CapturedEvent] {
        Array(day.events.prefix(4))
    }

    private var chapterFive: some View {
        chapterContainer(number: 5, title: "The week's capture") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(curatedMoments.enumerated()), id: \.element.id) { index, event in
                    momentCompact(event)
                    if index < curatedMoments.count - 1 {
                        Rectangle()
                            .fill(ReflectionTheme.borderLight)
                            .frame(height: 1)
                            .padding(.vertical, 14)
                    }
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReflectionTheme.borderLight, lineWidth: 1)
            )
        }
    }

    private func momentCompact(_ event: CapturedEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(event.time)
                .font(ReflectionTheme.mono(11))
                .foregroundColor(ReflectionTheme.mutedText)
                .frame(width: 66, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                SourceEyebrow(source: event.source)
                Text(event.text)
                    .font(ReflectionTheme.serif(14))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let trigger = event.trigger {
                    TriggerPill(trigger: trigger)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Chapter 6 · One question for next week

    private var chapterSix: some View {
        chapterContainer(number: 6, title: "One question for next week") {
            VStack(alignment: .leading, spacing: 20) {
                Text("“If you could only ship three things next week, which would they be?”")
                    .font(ReflectionTheme.serif(22, weight: .regular))
                    .italic()
                    .foregroundColor(ReflectionTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)

                TextEditor(text: $answerText)
                    .font(ReflectionTheme.serif(14))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .padding(12)
                    .frame(minHeight: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(cardBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ReflectionTheme.borderLight, lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    pillButton(label: "Save my answer", primary: true)
                }
            }
        }
    }

    // MARK: - Chapter 7 · Close the week

    private var chapterSeven: some View {
        chapterContainer(number: 7, title: "Close the week") {
            VStack(alignment: .leading, spacing: 18) {
                Text("When you're ready, archive this week's reflection. Pet will keep it for you — you can always come back.")
                    .font(ReflectionTheme.serif(15))
                    .foregroundColor(ReflectionTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            weekMarkedReviewed = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: weekMarkedReviewed ? "checkmark.seal.fill" : "seal")
                                .font(.system(size: 13, weight: .semibold))
                            Text(weekMarkedReviewed ? "Week archived" : "Mark week as reviewed")
                                .font(ReflectionTheme.sans(13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(weekMarkedReviewed ? ReflectionTheme.moodCalm : ReflectionTheme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(weekMarkedReviewed)

                    if weekMarkedReviewed {
                        Text("Saved to ~/.codepet/journal/week-apr-16-22.md")
                            .font(ReflectionTheme.mono(10))
                            .foregroundColor(ReflectionTheme.secondaryText)
                            .transition(.opacity)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(ReflectionTheme.borderLight)
                .frame(width: 60, height: 1)
                .padding(.bottom, 6)
            Text("Held for you, not over you.")
                .font(ReflectionTheme.serif(13))
                .italic()
                .foregroundColor(ReflectionTheme.mutedText)
            Text("— Nova")
                .font(ReflectionTheme.sans(10))
                .foregroundColor(ReflectionTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Chapter container

    @ViewBuilder
    private func chapterContainer<Content: View>(number: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Eyebrow(text: "Chapter \(number)")
                Rectangle()
                    .fill(ReflectionTheme.borderLight)
                    .frame(width: 24, height: 1)
                Eyebrow(text: title, color: ReflectionTheme.secondaryText)
            }
            content()
        }
    }

    // MARK: - Helpers

    private func pillButton(label: String, primary: Bool) -> some View {
        Text(label)
            .font(ReflectionTheme.sans(12, weight: primary ? .semibold : .medium))
            .foregroundColor(primary ? .white : ReflectionTheme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(primary ? ReflectionTheme.accent : ReflectionTheme.borderLight.opacity(0.5))
            )
    }
}

// MARK: - Safe index helper (local, avoids clashing with any existing global extension)

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    WeeklyReviewView()
        .frame(width: 820, height: 820)
}
