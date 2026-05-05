import SwiftUI

struct ReflectionTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var reflectionStore: ReflectionEventStore
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var enricher: NarrativeEnricher

    @State private var selectedTurnId: String? = nil
    @State private var hoveredTurnId: String? = nil

    // MARK: - Pet name

    private var petName: String {
        PetCharacter.all[appState.activeChar]?.name ?? ReflectionPet.name
    }

    // MARK: - Turn assembly from raw JSONL events (Step 4: clean version using rawJSONLEvents)

    private var allTurns: [Turn] {
        let inputs: [AssemblerInput] = reflectionStore.rawJSONLEvents.compactMap { entry in
            guard !entry.sessionId.isEmpty else { return nil }
            let kind: AssemblerInput.Kind
            switch entry.type {
            case "prompt":  kind = .prompt(text: entry.text)
            case "tool":    kind = .tool(text: entry.text)
            case "summary": kind = .summary(text: entry.text)
            default:        return nil
            }
            return AssemblerInput(kind: kind, isoTime: entry.isoTime, sessionId: entry.sessionId)
        }
        return TurnAssembler.assemble(
            inputs: inputs,
            now: Date(),
            narratives: narrativeStore.narratives
        )
    }

    private var selectedTurn: Turn? {
        guard let id = selectedTurnId else { return allTurns.first }
        return allTurns.first(where: { $0.id == id }) ?? allTurns.first
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sessionsSidebar
                .frame(width: 280)

            Divider()
                .background(ReflectionTheme.borderLight)

            Group {
                if let turn = selectedTurn {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 36) {
                            petHeader(for: turn)
                            turnBody(for: turn)
                            footer
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(ReflectionTheme.background)
        .onChange(of: allTurns) { turns in
            for turn in turns where turn.state == .summarizing && turn.narrative == nil {
                Task { await enricher.enrich(turn: turn) }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer()
            Text("Chưa có gì để phản tỉnh.")
                .font(ReflectionTheme.serif(20, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
                .multilineTextAlignment(.center)
            Text("Mở Claude Code và bắt đầu code — câu chuyện sẽ tự xuất hiện ở đây sau mỗi lượt làm việc.")
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Sidebar

    private struct SessionBucket: Identifiable {
        let sessionId: String
        let startedAt: Date
        let turns: [Turn]
        var id: String { sessionId }
    }

    private struct TurnGroup {
        let label: String
        let sessions: [SessionBucket]
    }

    /// Group turns by day, then by session within day. Sessions sorted by their
    /// most recent turn descending (newest activity first).
    private func groupedTurns() -> [TurnGroup] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let weekStart = cal.date(byAdding: .day, value: -6, to: today)!

        var bucketed: [String: [Turn]] = [
            "HÔM NAY": [], "HÔM QUA": [], "TUẦN NÀY": [], "CŨ HƠN": []
        ]
        for turn in allTurns {
            let day = cal.startOfDay(for: turn.startedAt)
            let key: String
            if day == today { key = "HÔM NAY" }
            else if day == yesterday { key = "HÔM QUA" }
            else if day >= weekStart { key = "TUẦN NÀY" }
            else { key = "CŨ HƠN" }
            bucketed[key, default: []].append(turn)
        }

        let order = ["HÔM NAY", "HÔM QUA", "TUẦN NÀY", "CŨ HƠN"]
        var groups: [TurnGroup] = []
        for label in order {
            let turns = bucketed[label] ?? []
            guard !turns.isEmpty else { continue }
            let sessions = sessionsFromTurns(turns)
            groups.append(.init(label: label, sessions: sessions))
        }
        return groups
    }

    private func sessionsFromTurns(_ turns: [Turn]) -> [SessionBucket] {
        var bySession: [String: [Turn]] = [:]
        for turn in turns { bySession[turn.sessionId, default: []].append(turn) }
        return bySession.map { sessionId, turns in
            let sortedTurns = turns.sorted { $0.startedAt > $1.startedAt }
            let earliest = turns.map { $0.startedAt }.min() ?? Date()
            return SessionBucket(sessionId: sessionId, startedAt: earliest, turns: sortedTurns)
        }
        .sorted { ($0.turns.first?.startedAt ?? .distantPast) > ($1.turns.first?.startedAt ?? .distantPast) }
    }

    private func sessionLabel(_ bucket: SessionBucket) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let start = f.string(from: bucket.startedAt)
        return "Phiên \(start) · \(bucket.turns.count) turn"
    }

    private var sessionsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    let groups = groupedTurns()
                    if groups.isEmpty {
                        Text("Chưa có lượt nào.")
                            .font(ReflectionTheme.sans(11))
                            .foregroundColor(ReflectionTheme.mutedText)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                    ForEach(groups, id: \.label) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.label)
                                .font(ReflectionTheme.sans(10, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(ReflectionTheme.mutedText)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 2)

                            ForEach(group.sessions) { bucket in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sessionLabel(bucket))
                                        .font(ReflectionTheme.sans(10, weight: .medium))
                                        .foregroundColor(ReflectionTheme.mutedText.opacity(0.85))
                                        .padding(.horizontal, 20)
                                        .padding(.top, 2)
                                        .padding(.bottom, 2)
                                    ForEach(bucket.turns) { turn in
                                        sidebarRow(turn)
                                    }
                                }
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

    private func sidebarRow(_ turn: Turn) -> some View {
        let isSelected = turn.id == selectedTurnId
        let isHovered = turn.id == hoveredTurnId
        return Button {
            selectedTurnId = turn.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(stateColor(turn.state))
                    .frame(width: 6, height: 6)
                    .padding(.top, 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sidebarTitle(for: turn))
                        .font(ReflectionTheme.sans(12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(ReflectionTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(timeDisplay(turn.startedAt))
                        .font(ReflectionTheme.sans(10.5))
                        .foregroundColor(ReflectionTheme.mutedText)
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
        .onHover { hoveredTurnId = $0 ? turn.id : nil }
    }

    private func sidebarTitle(for turn: Turn) -> String {
        if let title = turn.narrative?.title { return title }
        switch turn.state {
        case .pending, .summarizing: return "Đang tóm tắt…"
        case .pendingOrphan:         return "Phiên chưa hoàn thành"
        case .failed:                return "Không tóm tắt được"
        case .ready:                 return turn.prompt
        }
    }

    private func stateColor(_ state: TurnState) -> Color {
        switch state {
        case .ready:                    return ReflectionTheme.moodCalm
        case .summarizing, .pending:    return ReflectionTheme.accent
        case .failed:                   return ReflectionTheme.moodAlert
        case .pendingOrphan:            return ReflectionTheme.mutedText
        }
    }

    // MARK: - Pet header

    private func petHeader(for turn: Turn) -> some View {
        HStack(alignment: .center, spacing: 14) {
            PetAvatar(mood: .calm, size: 96)
            VStack(alignment: .leading, spacing: 8) {
                Text(petName)
                    .font(ReflectionTheme.serif(22, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text(dateDisplay(turn.startedAt))
                    .font(ReflectionTheme.sans(12))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer()
        }
    }

    // MARK: - Turn body

    @ViewBuilder
    private func turnBody(for turn: Turn) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            // Title + duration
            VStack(alignment: .leading, spacing: 8) {
                if let title = turn.narrative?.title {
                    Text(title)
                        .font(ReflectionTheme.serif(22, weight: .medium))
                        .foregroundColor(ReflectionTheme.primaryText)
                }
                HStack(spacing: 6) {
                    Text(timeDisplay(turn.startedAt))
                        .font(ReflectionTheme.sans(12))
                        .foregroundColor(ReflectionTheme.mutedText)
                    if let ended = turn.endedAt {
                        Text("·")
                            .foregroundColor(ReflectionTheme.mutedText)
                        Text("\(Int(ended.timeIntervalSince(turn.startedAt) / 60)) phút")
                            .font(ReflectionTheme.sans(12))
                            .foregroundColor(ReflectionTheme.mutedText)
                    }
                }
            }

            // Narrative or loading state
            if let narrative = turn.narrative {
                NarrativeChatView(narrative: narrative)
            } else {
                TurnLoadingStates(state: turn.state, onRetry: {
                    Task { await enricher.enrich(turn: turn) }
                })
            }

            // Collapsed technical details
            if !turn.rawEvents.isEmpty {
                TechnicalDetailsView(prompt: turn.prompt, events: turn.rawEvents)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Eyebrow(text: "CodePet v1.0 · reflection · captured quietly. shown on request.")
            Spacer()
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func timeDisplay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateDisplay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: date)
    }
}

#Preview {
    ReflectionTab()
        .environmentObject(AppState())
        .environmentObject(ReflectionEventStore())
        .environmentObject(NarrativeStore())
        .environmentObject(NarrativeEnricher(
            api: ReflectionAPIClient(),
            store: NarrativeStore(),
            language: "vi"
        ))
        .frame(width: 900, height: 800)
}
