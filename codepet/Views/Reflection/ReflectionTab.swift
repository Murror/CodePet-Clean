import SwiftUI

struct ReflectionTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var reflectionStore: ReflectionEventStore

    @State private var selectedSessionId: UUID = ReflectionMockData.sessions.first!.id
    @State private var expandedEventId: UUID? = nil
    @State private var hoveredEventId: UUID? = nil
    @State private var hoveredSessionId: UUID? = nil
    @State private var showResponseEditor = false
    @State private var responseText = ""
    @State private var savedConfirmationUntil: Date? = nil

    // Weekly review
    @State private var showWeeklyReview = false
    @State private var showSundayBanner = true   // hardcoded on for demo — in prod this'd be gated by date

    private var petName: String {
        PetCharacter.all[appState.activeChar]?.name ?? ReflectionPet.name
    }

    private var allSessions: [ReflectionSession] {
        if let live = reflectionStore.liveSession {
            return [live] + ReflectionMockData.sessions
        }
        return ReflectionMockData.sessions
    }

    private var selectedSession: ReflectionSession {
        allSessions.first(where: { $0.id == selectedSessionId }) ?? allSessions[0]
    }

    private var day: ReflectionDay { selectedSession.day }

    /// Resolve persona variant for any reflection prompt by its original headline.
    private func personaTitle(for session: ReflectionSession) -> String {
        PersonaContent.resolve(
            PersonaContent.reflectionHeadline,
            id: session.day.prompt.headline,
            persona: appState.languagePersona,
            fallback: session.day.prompt.headline
        )
    }

    private var personaPromptHeadline: String {
        PersonaContent.resolve(
            PersonaContent.reflectionHeadline,
            id: day.prompt.headline,
            persona: appState.languagePersona,
            fallback: day.prompt.headline
        )
    }

    private var personaPromptBody: String {
        PersonaContent.resolve(
            PersonaContent.reflectionBody,
            id: day.prompt.headline,
            persona: appState.languagePersona,
            fallback: day.prompt.body
        )
    }

    private var personaPromptProbe: String {
        PersonaContent.resolve(
            PersonaContent.reflectionProbe,
            id: day.prompt.headline,
            persona: appState.languagePersona,
            fallback: day.prompt.probe
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sessionsSidebar
                .frame(width: 280)

            Divider()
                .background(ReflectionTheme.borderLight)

            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    if showSundayBanner {
                        sundayBanner
                    }
                    header
                    mainGrid
                    footer
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .background(ReflectionTheme.background)
        .onChange(of: selectedSessionId) { _ in
            expandedEventId = nil
            showResponseEditor = false
            responseText = ""
        }
        .sheet(isPresented: $showWeeklyReview) {
            WeeklyReviewView(onClose: { showWeeklyReview = false })
                .frame(minWidth: 780, minHeight: 760)
        }
    }

    // MARK: Sessions sidebar (Claude/ChatGPT-style history)

    private var sessionsSidebar: some View {
        let grouped = groupedSessions()
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(ReflectionTheme.serif(16, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(grouped, id: \.group) { bucket in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bucket.group.uppercased())
                                .font(ReflectionTheme.sans(10, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(ReflectionTheme.mutedText)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 4)

                            ForEach(bucket.sessions) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0xFD / 255.0, green: 0xFC / 255.0, blue: 0xF8 / 255.0))
    }

    private func sessionRow(_ session: ReflectionSession) -> some View {
        let isSelected = session.id == selectedSessionId
        let isHovered = session.id == hoveredSessionId
        return Button {
            selectedSessionId = session.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                // Mood dot
                Circle()
                    .fill(ReflectionTheme.color(for: session.mood))
                    .frame(width: 6, height: 6)
                    .padding(.top, 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text(personaTitle(for: session))
                        .font(ReflectionTheme.sans(12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(ReflectionTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(session.dateDisplay)
                            .font(ReflectionTheme.sans(10.5))
                            .foregroundColor(ReflectionTheme.mutedText)
                        Text("·")
                            .font(ReflectionTheme.sans(10.5))
                            .foregroundColor(ReflectionTheme.mutedText.opacity(0.6))
                        Text(session.source.rawValue)
                            .font(ReflectionTheme.sans(10.5, weight: .medium))
                            .foregroundColor(ReflectionTheme.sourceTintFg(for: session.source).opacity(0.85))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? ReflectionTheme.accent.opacity(0.10)
                          : (isHovered ? Color.black.opacity(0.03) : Color.clear))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(ReflectionTheme.accent)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .onHover { hoveredSessionId = $0 ? session.id : nil }
    }

    private func groupedSessions() -> [(group: String, sessions: [ReflectionSession])] {
        var order: [String] = []
        var map: [String: [ReflectionSession]] = [:]
        for session in allSessions {
            if map[session.dateGroup] == nil { order.append(session.dateGroup) }
            map[session.dateGroup, default: []].append(session)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    // MARK: Sunday banner (auto-prompt)

    private var sundayBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ReflectionTheme.accent)
                .padding(10)
                .background(
                    Circle().fill(ReflectionTheme.accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("It's Sunday. Ready to close the week?")
                    .font(ReflectionTheme.serif(15, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text("Your weekly review takes about 5 minutes. Held for you, not over you.")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

            Spacer()

            Button {
                showWeeklyReview = true
            } label: {
                HStack(spacing: 6) {
                    Text("Start weekly review")
                        .font(ReflectionTheme.sans(12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(ReflectionTheme.accent)
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSundayBanner = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ReflectionTheme.mutedText)
                    .padding(6)
                    .background(
                        Circle().fill(ReflectionTheme.borderLight.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0xFB / 255.0, green: 0xF8 / 255.0, blue: 0xF0 / 255.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ReflectionTheme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                PetAvatar(mood: day.mood, size: 96)

                VStack(alignment: .leading, spacing: 8) {
                    Text(petName)
                        .font(ReflectionTheme.serif(22, weight: .medium))
                        .foregroundColor(ReflectionTheme.primaryText)

                    HStack(spacing: 6) {
                        Text(day.dateDisplay)
                            .font(ReflectionTheme.sans(12))
                            .foregroundColor(ReflectionTheme.mutedText)

                        Text("·")
                            .foregroundColor(ReflectionTheme.mutedText)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(ReflectionTheme.color(for: day.mood))
                                .frame(width: 6, height: 6)
                            Text(day.mood.label)
                                .font(ReflectionTheme.sans(12, weight: .medium))
                                .foregroundColor(ReflectionTheme.color(for: day.mood))
                        }
                    }

                    sessionSourceBadge
                }

                Spacer()

                if selectedSession.isWeekly {
                    Button {
                        showWeeklyReview = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Start weekly review")
                                .font(ReflectionTheme.sans(12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8).fill(ReflectionTheme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Source badge (each session is tied to exactly one IDE)

    private var sessionSourceBadge: some View {
        let source = selectedSession.source
        return HStack(spacing: 6) {
            Circle()
                .fill(ReflectionTheme.sourceTintFg(for: source))
                .frame(width: 5, height: 5)
            Text(source.rawValue)
                .font(ReflectionTheme.sans(10, weight: .semibold))
                .foregroundColor(ReflectionTheme.sourceTintFg(for: source))
                .tracking(0.3)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(ReflectionTheme.sourceTintBg(for: source))
        )
    }

    // MARK: Inline stats strip (small — moments are the focus)

    private var inlineStats: some View {
        HStack(spacing: 14) {
            inlineStat(number: day.captured, label: "captured", accent: false)
            divider
            inlineStat(number: day.decisions, label: "decisions", accent: false)
            divider
            inlineStat(number: day.risks, label: "risks", accent: day.risks > 0)
        }
    }

    private func inlineStat(number: Int, label: String, accent: Bool) -> some View {
        HStack(spacing: 5) {
            Text("\(number)")
                .font(ReflectionTheme.serif(14, weight: .medium))
                .foregroundColor(accent ? ReflectionTheme.accent : ReflectionTheme.primaryText)
            Text(label)
                .font(ReflectionTheme.sans(11))
                .foregroundColor(accent ? ReflectionTheme.accent.opacity(0.85) : ReflectionTheme.mutedText)
        }
    }

    private var divider: some View {
        Text("·")
            .font(ReflectionTheme.sans(11))
            .foregroundColor(ReflectionTheme.mutedText.opacity(0.6))
    }

    // MARK: Main grid

    private var mainGrid: some View {
        HStack(alignment: .top, spacing: 36) {
            momentsSection
                .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 32) {
                patternsSection
                reflectionSection
            }
            .frame(width: 320)
        }
    }

    // MARK: Moments

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: "Moments")
                Spacer()
                inlineStats
            }
            .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                    momentRow(event: event, isLast: index == day.events.count - 1)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ReflectionTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ReflectionTheme.borderLight, lineWidth: 1)
            )
        }
    }

    private func momentRow(event: CapturedEvent, isLast: Bool) -> some View {
        let isExpanded = expandedEventId == event.id
        let isHovered = hoveredEventId == event.id

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedEventId = isExpanded ? nil : event.id
                }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    Text(event.time)
                        .font(ReflectionTheme.mono(11))
                        .foregroundColor(ReflectionTheme.mutedText)
                        .frame(width: 52, alignment: .leading)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.text)
                            .font(ReflectionTheme.sans(14))
                            .foregroundColor(ReflectionTheme.primaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let summary = event.aiSummary {
                            HStack(alignment: .top, spacing: 6) {
                                Text("↳")
                                    .font(ReflectionTheme.sans(12))
                                    .foregroundColor(ReflectionTheme.mutedText)
                                Text(summary)
                                    .font(ReflectionTheme.sans(12))
                                    .italic()
                                    .foregroundColor(ReflectionTheme.mutedText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if let trigger = event.trigger {
                            HStack(spacing: 8) {
                                TriggerPill(trigger: trigger)
                                Text("\(Int(trigger.confidence * 100))%")
                                    .font(ReflectionTheme.mono(10))
                                    .foregroundColor(ReflectionTheme.mutedText)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    if event.context != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ReflectionTheme.mutedText)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(isHovered ? ReflectionTheme.background.opacity(0.6) : Color.clear)
            .onHover { hovering in
                hoveredEventId = hovering ? event.id : nil
            }

            if isExpanded, let context = event.context {
                HStack(alignment: .top, spacing: 10) {
                    Rectangle()
                        .fill(ReflectionTheme.accent)
                        .frame(width: 2)
                    Text(context)
                        .font(ReflectionTheme.serif(13))
                        .italic()
                        .foregroundColor(ReflectionTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .padding(.leading, 66)
                .transition(.opacity)
            }

            if !isLast {
                Rectangle()
                    .fill(ReflectionTheme.borderLight)
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
        }
    }

    // MARK: Patterns

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Patterns")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(day.patterns.enumerated()), id: \.element.id) { index, pattern in
                    patternRow(pattern)
                    if index < day.patterns.count - 1 {
                        Rectangle()
                            .fill(ReflectionTheme.borderLight)
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ReflectionTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ReflectionTheme.borderLight, lineWidth: 1)
            )
        }
    }

    private func patternRow(_ pattern: PatternSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(pattern.triggerCode) · \(pattern.label)")
                    .font(ReflectionTheme.sans(12, weight: .semibold))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text(pattern.deltaText)
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(pattern.count)")
                    .font(ReflectionTheme.serif(26, weight: .regular))
                    .foregroundColor(ReflectionTheme.primaryText)
                trendGlyph(pattern.trend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func trendGlyph(_ trend: PatternTrend) -> some View {
        Group {
            switch trend {
            case .up:
                Image(systemName: "arrow.up.right")
                    .foregroundColor(ReflectionTheme.moodAlert)
            case .down:
                Image(systemName: "arrow.down.right")
                    .foregroundColor(ReflectionTheme.moodCalm)
            case .flat:
                Image(systemName: "arrow.right")
                    .foregroundColor(ReflectionTheme.mutedText)
            case .new:
                Text("NEW")
                    .font(ReflectionTheme.sans(8, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(ReflectionTheme.accent)
            }
        }
        .font(.system(size: 10, weight: .semibold))
    }

    // MARK: Reflection section

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Reflection")

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(ReflectionTheme.accent)
                        .frame(width: 3)
                        .cornerRadius(1.5)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(personaPromptHeadline)
                            .font(ReflectionTheme.serif(18, weight: .medium))
                            .foregroundColor(ReflectionTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(personaPromptBody)
                            .font(ReflectionTheme.serif(14))
                            .foregroundColor(ReflectionTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(personaPromptProbe)
                            .font(ReflectionTheme.serif(14, weight: .medium))
                            .italic()
                            .foregroundColor(ReflectionTheme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(day.prompt.sourceCitation)
                    .font(ReflectionTheme.mono(10))
                    .foregroundColor(ReflectionTheme.mutedText)

                if showResponseEditor {
                    responseEditor
                } else {
                    reflectionActions
                }

                if let until = savedConfirmationUntil, until > Date() {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ReflectionTheme.moodCalm)
                            .font(.system(size: 12))
                        Text("Saved to ~/.codepet/journal/\(journalFilename)")
                            .font(ReflectionTheme.mono(10))
                            .foregroundColor(ReflectionTheme.secondaryText)
                    }
                    .transition(.opacity)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ReflectionTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ReflectionTheme.borderLight, lineWidth: 1)
            )
        }
    }

    private var reflectionActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showResponseEditor = true
                }
            } label: {
                actionLabel("Write a response", primary: true)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button {
                    triggerSaveConfirmation()
                } label: {
                    actionLabel("Save as journal entry", primary: false)
                }
                .buttonStyle(.plain)

                Button {
                    // acknowledge and clear — keep it simple for demo
                    withAnimation(.easeInOut(duration: 0.18)) {
                        expandedEventId = nil
                        showResponseEditor = false
                    }
                } label: {
                    actionLabel("Not useful this time", primary: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionLabel(_ text: String, primary: Bool) -> some View {
        Text(text)
            .font(ReflectionTheme.sans(12, weight: primary ? .semibold : .medium))
            .foregroundColor(primary ? .white : ReflectionTheme.secondaryText)
            .lineLimit(1)
            .fixedSize(horizontal: !primary, vertical: false)
            .padding(.horizontal, primary ? 12 : 10)
            .padding(.vertical, 8)
            .frame(maxWidth: primary ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(primary ? ReflectionTheme.accent : ReflectionTheme.borderLight.opacity(0.5))
            )
    }

    private var responseEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $responseText)
                .font(ReflectionTheme.serif(13))
                .foregroundColor(ReflectionTheme.primaryText)
                .padding(8)
                .frame(minHeight: 88)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ReflectionTheme.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ReflectionTheme.borderLight, lineWidth: 1)
                )

            HStack(spacing: 8) {
                Button {
                    triggerSaveConfirmation()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showResponseEditor = false
                        responseText = ""
                    }
                } label: {
                    actionLabel("Save response", primary: true)
                }
                .buttonStyle(.plain)
                .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showResponseEditor = false
                        responseText = ""
                    }
                } label: {
                    actionLabel("Cancel", primary: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var journalFilename: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd-HHmm"
        return "\(fmt.string(from: Date())).md"
    }

    private func triggerSaveConfirmation() {
        withAnimation(.easeInOut(duration: 0.18)) {
            savedConfirmationUntil = Date().addingTimeInterval(3)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.05) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if let until = savedConfirmationUntil, until <= Date() {
                    savedConfirmationUntil = nil
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Spacer()
            Eyebrow(text: "CodePet v1.0 · reflection · captured quietly. shown on request.")
            Spacer()
        }
        .padding(.top, 12)
    }
}

#Preview {
    ReflectionTab()
        .environmentObject(AppState())
        .environmentObject(ReflectionEventStore())
        .frame(width: 900, height: 800)
}
