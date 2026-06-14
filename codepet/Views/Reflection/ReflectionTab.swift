import SwiftUI

struct ReflectionTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var reflectionStore: ReflectionEventStore
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var summaryStore: SessionSummaryStore
    @EnvironmentObject var enricher: NarrativeEnricher
    @EnvironmentObject var endStore: SessionEndStore
    @EnvironmentObject var sessionEnricher: SessionSummaryEnricher
    @EnvironmentObject var chatStore: SessionChatStore
    @EnvironmentObject var chatController: SessionChatController
    @EnvironmentObject var demo: DemoScriptController
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var healthNudge: HealthNudgeController
    @Environment(\.uiLanguage) private var uiLanguage

    @State private var selectedSessionId: String? = nil
    @State private var hoveredSessionId: String? = nil
    @State private var chatExpanded = false
    @State private var sidebarCollapsed = false
    /// Tracks which project groups are collapsed in the sidebar.
    /// By default all groups are expanded (not in this set).
    @State private var collapsedProjects: Set<String> = []

    // MARK: - Cached session data (avoids recomputing on every body evaluation)

    /// Cached sessions — rebuilt only when upstream stores actually change.
    @State private var cachedSessions: [Session] = []
    /// Cached project groups — rebuilt alongside cachedSessions.
    @State private var cachedGroups: [ProjectGroup] = []
    /// Input fingerprint: incremented when any upstream dependency publishes new data.
    /// onChange(of: dataVersion) triggers a single recompute of sessions + groups.
    @State private var dataVersion: Int = 0

    // MARK: - Pet name

    private var petName: String {
        PetCharacter.all[appState.activeChar]?.name ?? ReflectionPet.name
    }

    // MARK: - Turn + Session assembly (cached)

    /// Recompute turns → sessions → groups. Called from onChange, NOT from the view body.
    private func recomputeSessionData() {
        let sessions: [Session]
        if appState.demoModeEnabled {
            sessions = [Session.makeWelcome()] + (demo.demoSession.map { [$0] } ?? [])
        } else {
            let inputs: [AssemblerInput] = reflectionStore.rawJSONLEvents.compactMap { entry in
                guard !entry.sessionId.isEmpty else { return nil }
                let kind: AssemblerInput.Kind
                switch entry.type {
                case "prompt":  kind = .prompt(text: entry.text)
                case "tool":    kind = .tool(text: entry.text)
                case "summary": kind = .summary(text: entry.text)
                default:        return nil
                }
                return AssemblerInput(kind: kind, isoTime: entry.isoTime, sessionId: entry.sessionId, cwd: entry.cwd, path: entry.path)
            }
            let turns = TurnAssembler.assemble(
                inputs: inputs,
                now: Date(),
                narratives: narrativeStore.narratives,
                failedTurns: enricher.failedTurns
            )
            let real = TurnAssembler.assembleSessions(
                turns: turns,
                summaries: summaryStore.summaries
            )
            sessions = [Session.makeWelcome()] + real
        }
        cachedSessions = sessions
        cachedGroups = buildProjectGroups(from: sessions)
    }

    private var selectedSession: Session? {
        if appState.demoModeEnabled, let demoSess = demo.demoSession {
            return demoSess
        }
        if let id = selectedSessionId,
           let match = cachedSessions.first(where: { $0.id == id }) {
            return match
        }
        return cachedSessions.first
    }

    // MARK: - Body

    var body: some View {
        normalBody
    }

    private var normalBody: some View {
        HStack(alignment: .top, spacing: 0) {
            if sidebarCollapsed {
                // Collapsed: narrow strip with toggle + session icons
                collapsedSidebarStrip
            } else {
                sessionsSidebar
                    .frame(width: 280)
            }

            Group {
                if let session = selectedSession {
                    VStack(spacing: 0) {
                        // Health nudge banner — slides in when the pet wants the user to take a break
                        if let nudge = healthNudge.activeNudge {
                            HealthNudgeBanner(nudge: nudge, onDismiss: { healthNudge.dismiss() })
                                .padding(.horizontal, 40)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 36) {
                                if session.isWelcome {
                                    WelcomeSessionView()
                                } else {
                                    // Project brief card — shown when session belongs to a detected project
                                    if let resolved = projectStore.resolvedProjectPath(for: session.projectPath, sessionId: session.id),
                                       !resolved.isEmpty {
                                        ProjectBriefCard(projectPath: resolved)
                                    }
                                    petHeader(for: session)
                                    sessionBody(for: session)
                                    footer
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 32)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity)

            // Right-docked chat sidebar (open state)
            if let session = selectedSession, !session.isWelcome, chatExpanded {
                Divider()
                    .background(ReflectionTheme.borderLight)
                SessionChatPanel(
                    session: session,
                    onClose: {
                        if chatController.inFlightSessionId == session.id {
                            chatController.cancel()
                        }
                        chatExpanded = false
                    },
                    onSend: { text in
                        let request = makeChatRequest(for: session, userMessage: text)
                        Task {
                            await chatController.send(
                                userText: text,
                                sessionId: session.id,
                                request: request
                            )
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(ReflectionTheme.background)
        .overlay(alignment: .bottomTrailing) {
            // Floating launcher bubble — only visible when chat is collapsed.
            if let session = selectedSession, !session.isWelcome, !chatExpanded {
                SessionChatBubble(onTap: { chatExpanded = true })
                    .padding(16)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeOut(duration: 0.22), value: chatExpanded)
        .animation(.easeInOut(duration: 0.2), value: sidebarCollapsed)
        // NOTE: collapsedProjects animation is scoped to projectGroupSection
        // via .animation(.easeOut(duration: 0.12), value: isCollapsed) — do NOT
        // add a top-level .animation(value: collapsedProjects) here as it would
        // animate unrelated parts of the tree.
        .background {
            // Hidden button to capture ⌘B keyboard shortcut
            Button("") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sidebarCollapsed.toggle()
                }
            }
            .keyboardShortcut("b", modifiers: .command)
            .hidden()
        }
        .onAppear {
            // Initial data load — runs once on first render.
            recomputeSessionData()
            registerNewProjects()
            publishActiveProject()

            // Tips tab deep-link: when arriving on Reflection with a pending
            // chat prompt, auto-select the most recent real session and open chat.
            // This must live in onAppear (not onChange) because MainTabView uses a
            // switch statement that recreates ReflectionTab on every tab change,
            // so onChange(of: selectedTab) never fires — the value is already
            // .reflection by the time the new view instance is created.
            if appState.pendingChatPrompt != nil {
                if let mostRecent = cachedSessions.first(where: { !$0.isWelcome }) {
                    selectedSessionId = mostRecent.id
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
                        withAnimation(.easeOut(duration: 0.22)) {
                            chatExpanded = true
                        }
                    }
                }
            }
        }
        // --- Data version bumpers: each upstream @Published change increments
        // the version counter. Only ONE recompute fires per runloop cycle.
        .onChange(of: reflectionStore.rawJSONLEvents.count) { _ in
            dataVersion += 1
            // New coding events arrived — mark the session as active so the
            // health nudge timer starts counting.
            healthNudge.markActive()
        }
        .onChange(of: narrativeStore.narratives.count) { _ in dataVersion += 1 }
        .onChange(of: summaryStore.summaries.count) { _ in dataVersion += 1 }
        .onChange(of: enricher.failedTurns.count) { _ in dataVersion += 1 }
        .onChange(of: appState.demoModeEnabled) { _ in dataVersion += 1 }
        // --- Single recompute when any upstream data changes
        .onChange(of: dataVersion) { _ in
            recomputeSessionData()
            registerNewProjects()

            guard !appState.demoModeEnabled else { return }
            let persona = currentPetPersona()
            for session in cachedSessions {
                for turn in session.turns where turn.state == .summarizing && turn.narrative == nil {
                    Task { await enricher.enrich(turn: turn, petPersona: persona) }
                }
            }
            autoSummarizeIfNeeded(sessions: cachedSessions, persona: persona)
            // The default selection (most recent session) may have changed as
            // data loaded — keep Project Health's focused project in sync.
            publishActiveProject()
        }
        .onChange(of: endStore.endedSessionIds) { _ in
            // A session just ended — recompute then check auto-summarize.
            recomputeSessionData()
            guard !appState.demoModeEnabled else { return }
            let persona = currentPetPersona()
            autoSummarizeIfNeeded(sessions: cachedSessions, persona: persona)
        }
        .onChange(of: selectedSessionId) { newId in
            // The focused session changed — sync Project Health's active project.
            publishActiveProject()
            // Auto-expand the project group that contains the selected session.
            guard let sid = newId else { return }
            for group in cachedGroups {
                if group.sessions.contains(where: { $0.id == sid }) {
                    collapsedProjects.remove(group.id)
                    break
                }
            }
        }
    }

    /// Publish the currently-focused project to the shared ProjectStore so the
    /// Tips tab's Project Health surfaces the same project as its active folder
    /// tab. The welcome session (and anything that doesn't resolve to a detected
    /// project) clears the focus.
    private func publishActiveProject() {
        guard let session = selectedSession, !session.isWelcome else {
            projectStore.setActiveProject(nil)
            return
        }
        let resolved = projectStore.resolvedProjectPath(for: session.projectPath, sessionId: session.id)
        projectStore.setActiveProject(resolved)
    }

    private func currentPetPersona() -> SummarizeTurnRequest.PetPersonaDTO? {
        guard let pet = PetCharacter.all[appState.activeChar] else { return nil }
        return SummarizeTurnRequest.PetPersonaDTO(
            id: pet.id,
            name: pet.name,
            personality: pet.personality,
            domain: pet.domain,
            voiceGuide: pet.voiceGuide,
            lensGuide: pet.lensGuide,
            emotionalTriggers: pet.emotionalTriggers,
            metaphorFamily: pet.metaphorFamily,
            signatureEmojis: pet.signatureEmojis
        )
    }

    private func makeChatRequest(for session: Session, userMessage: String) -> ChatSessionRequest {
        let history = chatStore.historySnapshot(for: session.id, lastN: 10)
            .map { ChatSessionRequest.ChatMessageDTO(role: $0.role.rawValue, text: $0.text) }
        let resolvedPath = projectStore.resolvedProjectPath(for: session.projectPath, sessionId: session.id)
        let context = ReflectionComposition.makeChatContext(
            for: session,
            userBrief: projectStore.brief(for: resolvedPath).isEmpty
                ? NarrativeEnricher.currentUserBrief(projectPath: resolvedPath)
                : projectStore.brief(for: resolvedPath)
        )
        let language = Locale.current.identifier.hasPrefix("vi") ? "vi" : "en"
        return ChatSessionRequest(
            sessionId: session.id,
            language: language,
            petPersona: currentPetPersona(),
            sessionContext: context,
            history: history,
            userMessage: userMessage
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer()
            Text(uiLanguage == .vi
                 ? "Chưa có gì để nhìn lại."
                 : "Nothing to reflect on yet.")
                .font(ReflectionTheme.serif(20, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
                .multilineTextAlignment(.center)
            Text(uiLanguage == .vi
                 ? "Mở Claude Code và bắt đầu code — câu chuyện của bạn sẽ hiện ở đây sau mỗi phiên làm việc."
                 : "Open Claude Code and start coding — your story will appear here after each working session.")
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

    private struct ProjectGroup: Identifiable {
        let projectPath: String?     // nil = ungrouped sessions
        let displayName: String
        let sessions: [Session]
        var id: String { projectPath ?? "__ungrouped__" }
    }

    /// Build project groups from a pre-computed session list. Pure function — no I/O.
    /// Called from `recomputeSessionData()`, NOT from the view body.
    private func buildProjectGroups(from sessions: [Session]) -> [ProjectGroup] {
        var byProject: [String: [Session]] = [:]  // projectPath → sessions
        var ungrouped: [Session] = []

        for session in sessions where !session.isWelcome {
            if let resolved = projectStore.resolvedProjectPath(for: session.projectPath, sessionId: session.id),
               !resolved.isEmpty {
                byProject[resolved, default: []].append(session)
            } else {
                ungrouped.append(session)
            }
        }

        var groups: [ProjectGroup] = byProject.map { path, sessions in
            let name = projectStore.project(for: path)?.displayName ?? Project.nameFromPath(path)
            return ProjectGroup(
                projectPath: path,
                displayName: name,
                sessions: sessions.sorted { ($0.turns.last?.startedAt ?? .distantPast) > ($1.turns.last?.startedAt ?? .distantPast) }
            )
        }
        // Sort project groups by most-recent session
        groups.sort { group1, group2 in
            let t1 = group1.sessions.first?.turns.last?.startedAt ?? .distantPast
            let t2 = group2.sessions.first?.turns.last?.startedAt ?? .distantPast
            return t1 > t2
        }

        // Append ungrouped sessions at the end if any
        if !ungrouped.isEmpty {
            let label = uiLanguage == .vi ? "Khác" : "Other"
            groups.append(ProjectGroup(
                projectPath: nil,
                displayName: label,
                sessions: ungrouped.sorted { ($0.turns.last?.startedAt ?? .distantPast) > ($1.turns.last?.startedAt ?? .distantPast) }
            ))
        }

        return groups
    }

    /// Register any new project paths found in sessions. Called from `.onChange`
    /// (not from the view body) so @Published mutations don't trigger
    /// "Publishing changes from within view updates" warnings.
    /// Register projects and build the cwd → root resolution cache.
    /// Called from `.onChange(of: dataVersion)` — NOT from the view body.
    private func registerNewProjects() {
        for session in cachedSessions where !session.isWelcome {
            if let path = session.projectPath, !path.isEmpty {
                // Always call detectProject so the cwd → root cache stays warm,
                // even for already-known projects. detectProject is cheap for
                // existing entries (just updates lastSeenAt).
                projectStore.detectProject(cwd: path, filePaths: session.filePaths, sessionId: session.id)
            } else if !session.filePaths.isEmpty {
                // Session has no cwd but does have file paths — try to resolve
                // project from the file paths alone.
                projectStore.detectProjectFromFilePaths(session.filePaths, sessionId: session.id)
            }
        }
    }

    /// Auto-summarize sessions that are ended or idle. Fires when:
    ///   - a SessionEnd signal arrives (user closed the Claude Code session), OR
    ///   - a session has been idle > 30 min with no summary
    private func autoSummarizeIfNeeded(
        sessions: [Session],
        persona: SummarizeTurnRequest.PetPersonaDTO?
    ) {
        let ended = endStore.endedSessionIds
        for session in sessions where !session.isWelcome {
            guard sessionEnricher.shouldAutoSummarize(session: session, endedSessionIds: ended) else { continue }
            Task { await sessionEnricher.enrich(session: session, petPersona: persona, isAutoTriggered: true) }
        }
    }

    private func sessionRowTitle(for session: Session) -> String {
        // 1. First sentence of summary (≤60 chars)
        if let summaryText = session.summary?.summary {
            let firstSentence = summaryText.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? summaryText
            let truncated = String(firstSentence.prefix(60))
            if !truncated.isEmpty { return truncated }
        }
        // 2. Newest turn narrative title
        let newestTurn = session.turns.last
        if let title = newestTurn?.narrative?.title { return title }
        // 3. Fallback: "Session HH:mm"
        let prefix = uiLanguage == .vi ? "Phiên" : "Session"
        return "\(prefix) \(timeDisplay(session.startedAt))"
    }

    private func sessionMetaLabel(for session: Session) -> String {
        let turnCount = session.turns.count
        let turnWord: String
        switch uiLanguage {
        case .vi: turnWord = "lượt"
        case .en: turnWord = turnCount == 1 ? "turn" : "turns"
        }
        let minWord = uiLanguage == .vi ? "phút" : "min"
        var parts = [relativeDateLabel(session.startedAt), timeDisplay(session.startedAt), "\(turnCount) \(turnWord)"]
        if let ended = session.endedAt {
            let mins = Int(ended.timeIntervalSince(session.startedAt) / 60)
            if mins > 0 { parts.append("\(mins) \(minWord)") }
        }
        return parts.joined(separator: " · ")
    }

    /// Short relative date label for session rows (since we no longer group by day).
    private func relativeDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let day = cal.startOfDay(for: date)
        if day == today {
            return uiLanguage == .vi ? "Hôm nay" : "Today"
        }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        if day == yesterday {
            return uiLanguage == .vi ? "Hôm qua" : "Yesterday"
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - Collapsed sidebar strip

    private var collapsedSidebarStrip: some View {
        VStack(spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sidebarCollapsed = false
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ReflectionTheme.mutedText)
                    .frame(width: 40, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(uiLanguage == .vi ? "Mở thanh bên (⌘B)" : "Expand sidebar (⌘B)")
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Session dots — clickable mini indicators
            ScrollView {
                VStack(spacing: 12) {
                    // Welcome icon
                    Button {
                        selectedSessionId = Session.makeWelcome().id
                    } label: {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(
                                selectedSessionId == Session.makeWelcome().id
                                    ? ReflectionTheme.accent
                                    : ReflectionTheme.mutedText.opacity(0.5)
                            )
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedSessionId == Session.makeWelcome().id
                                          ? ReflectionTheme.accent.opacity(0.12)
                                          : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(uiLanguage == .vi ? "Bắt đầu" : "Get started")

                    // Session dots — uses cached groups
                    ForEach(cachedGroups) { group in
                        ForEach(group.sessions) { session in
                            Button {
                                selectedSessionId = session.id
                            } label: {
                                Circle()
                                    .fill(session.id == selectedSessionId
                                          ? ReflectionTheme.accent
                                          : sessionStateColor(session))
                                    .frame(width: session.id == selectedSessionId ? 8 : 6,
                                           height: session.id == selectedSessionId ? 8 : 6)
                                    .frame(width: 28, height: 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(session.id == selectedSessionId
                                                  ? ReflectionTheme.accent.opacity(0.08)
                                                  : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(sessionRowTitle(for: session))
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            Spacer()
        }
        .frame(width: 40)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [ReflectionTheme.sidebarTop, ReflectionTheme.sidebarBottom],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - Full sessions sidebar

    private var sessionsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Sidebar toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ReflectionTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ReflectionTheme.accent.opacity(0.12))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(uiLanguage == .vi ? "Ẩn thanh bên (⌘B)" : "Collapse sidebar (⌘B)")

                if !sidebarCollapsed {
                    Text(uiLanguage == .vi ? "Phiên" : "Sessions")
                        .font(ReflectionTheme.serif(16, weight: .semibold))
                        .foregroundColor(ReflectionTheme.primaryText)
                }
                Spacer()
            }
            .padding(.horizontal, sidebarCollapsed ? 8 : 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Welcome group — always pinned at top
                    VStack(alignment: .leading, spacing: 10) {
                        welcomeSidebarRow(Session.makeWelcome())
                    }

                    // Project-grouped sessions (collapsible) — uses cached groups
                    ForEach(cachedGroups) { group in
                        projectGroupSection(group)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [ReflectionTheme.sidebarTop, ReflectionTheme.sidebarBottom],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ReflectionTheme.sidebarBorder)
                .frame(width: 0.5)
        }
    }

    /// A single collapsible project group. Sessions stay in the view tree
    /// (hidden via height + opacity) so SwiftUI doesn't diff-insert/remove
    /// the entire ForEach on every toggle — this is what makes it fast.
    @ViewBuilder
    private func projectGroupSection(_ group: ProjectGroup) -> some View {
        let isCollapsed = collapsedProjects.contains(group.id)
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button {
                withAnimation(.easeOut(duration: 0.12)) {
                    if isCollapsed {
                        collapsedProjects.remove(group.id)
                    } else {
                        collapsedProjects.insert(group.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(ReflectionTheme.accent.opacity(0.6))
                        .frame(width: 10)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    Circle()
                        .fill(ReflectionTheme.accent)
                        .frame(width: 6, height: 6)
                    Text(group.displayName.uppercased())
                        .font(CodepetTheme.pixel(12))
                        .tracking(1.2)
                        .foregroundColor(ReflectionTheme.accent)
                    Spacer()
                    Text("\(group.sessions.count)")
                        .font(ReflectionTheme.sans(9, weight: .semibold))
                        .foregroundColor(ReflectionTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ReflectionTheme.accent.opacity(0.12))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Session rows — always in the tree, just clamped to zero height when collapsed
            VStack(alignment: .leading, spacing: 10) {
                ForEach(group.sessions) { session in
                    sidebarSessionRow(session)
                }
            }
            .padding(.top, isCollapsed ? 0 : 10)
            .frame(maxHeight: isCollapsed ? 0 : .infinity)
            .clipped()
            .opacity(isCollapsed ? 0 : 1)
            .allowsHitTesting(!isCollapsed)
        }
        .animation(.easeOut(duration: 0.12), value: isCollapsed)
    }

    private func welcomeSidebarRow(_ session: Session) -> some View {
        let isSelected = session.id == selectedSessionId
        return Button {
            selectedSessionId = session.id
        } label: {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ReflectionTheme.accent.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ReflectionTheme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(uiLanguage == .vi ? "Bắt đầu" : "Get started")
                        .font(ReflectionTheme.sans(12.5, weight: .semibold))
                        .foregroundColor(ReflectionTheme.accent)
                    Text(uiLanguage == .vi
                         ? "Kết nối Claude Code để bắt đầu"
                         : "Connect Claude Code to begin")
                        .font(ReflectionTheme.sans(10.5))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? LinearGradient(colors: [ReflectionTheme.accent.opacity(0.18), ReflectionTheme.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [ReflectionTheme.accent.opacity(0.05), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private func sidebarSessionRow(_ session: Session) -> some View {
        let isSelected = session.id == selectedSessionId
        let isHovered = session.id == hoveredSessionId
        let isLive = sessionStateColor(session) == ReflectionTheme.accent
        return Button {
            selectedSessionId = session.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(sessionStateColor(session))
                    .frame(width: isLive ? 8 : 6, height: isLive ? 8 : 6)
                    .padding(.top, isLive ? 6 : 7)
                    .shadow(color: isLive ? ReflectionTheme.accent.opacity(0.5) : .clear, radius: isLive ? 4 : 0)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sessionRowTitle(for: session))
                        .font(ReflectionTheme.sans(12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? ReflectionTheme.primaryText : ReflectionTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(sessionMetaLabel(for: session))
                        .font(ReflectionTheme.sans(10.5))
                        .foregroundColor(ReflectionTheme.mutedText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? LinearGradient(
                              colors: [ReflectionTheme.accent.opacity(0.15), ReflectionTheme.accent.opacity(0.06)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(
                              colors: [isHovered ? Color.black.opacity(0.03) : Color.clear,
                                       isHovered ? Color.black.opacity(0.01) : Color.clear],
                              startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ReflectionTheme.accent)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .onHover { hoveredSessionId = $0 ? session.id : nil }
        .contextMenu {
            moveToProjectMenu(session: session)
        }
    }

    /// Right-click "Move to…" submenu — lists all known projects.
    @ViewBuilder
    private func moveToProjectMenu(session: Session) -> some View {
        let currentResolved = projectStore.resolvedProjectPath(for: session.projectPath, sessionId: session.id)
        Menu(uiLanguage == .vi ? "Chuyển sang dự án…" : "Move to project…") {
            ForEach(projectStore.sortedProjects) { project in
                if project.id != currentResolved {
                    Button {
                        projectStore.assignSession(session.id, to: project.id)
                    } label: {
                        Label(project.displayName, systemImage: "folder")
                    }
                }
            }
        }
    }

    /// Color represents the "worst" state among the session's turns.
    private func sessionStateColor(_ session: Session) -> Color {
        let hasFailed = session.turns.contains {
            if case .failed = $0.state { return true }
            return false
        }
        if hasFailed { return ReflectionTheme.moodAlert }
        let hasSummarizing = session.turns.contains { $0.state == .summarizing || $0.state == .pending }
        if hasSummarizing { return ReflectionTheme.accent }
        return ReflectionTheme.moodCalm
    }

    // MARK: - Pet header (session level)

    @ViewBuilder
    private func petHeader(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                PetAvatar(mood: .calm, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(petName)
                        .font(ReflectionTheme.serif(18, weight: .medium))
                        .foregroundColor(ReflectionTheme.primaryText)
                    Text(dateDisplay(session.startedAt))
                        .font(ReflectionTheme.sans(11))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Spacer()
            }

            // "Last time on this project" reminder — shows previous session's
            // summary so the user remembers where they left off.
            if let prev = previousSession(for: session),
               let summary = prev.summary {
                let durationMinutes: Int? = {
                    guard let ended = prev.endedAt else { return nil }
                    let mins = Int(ended.timeIntervalSince(prev.startedAt) / 60)
                    return mins > 0 ? mins : nil
                }()
                LastTimeReminderView(
                    summary: summary,
                    sessionDate: prev.endedAt ?? prev.startedAt,
                    sessionDurationMinutes: durationMinutes
                )
                .padding(.leading, 68) // align with text, past the 56px avatar + 12px gap
                .padding(.top, 12)
            }
        }
    }

    /// Find the session immediately before `session` in the same project.
    /// Returns nil if this is the first session or no previous session has a summary.
    private func previousSession(for session: Session) -> Session? {
        let resolvedPath = projectStore.resolvedProjectPath(for: session.projectPath, sessionId: session.id)
        guard let path = resolvedPath, !path.isEmpty else { return nil }

        // Find the project group that contains this session
        guard let group = cachedGroups.first(where: { $0.projectPath == path }) else { return nil }

        // Sessions in the group are sorted newest-first; we need the one right after `session`
        // (i.e. the previous session chronologically).
        let sorted = group.sessions.sorted {
            ($0.turns.last?.startedAt ?? .distantPast) > ($1.turns.last?.startedAt ?? .distantPast)
        }
        guard let idx = sorted.firstIndex(where: { $0.id == session.id }),
              idx + 1 < sorted.count else { return nil }

        let candidate = sorted[idx + 1]
        // Only show if the previous session actually has a summary
        guard candidate.summary != nil else { return nil }
        return candidate
    }

    // MARK: - Session body

    @ViewBuilder
    private func sessionBody(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            // Session header strip
            sessionHeaderStrip(for: session)

            // Pet recap up top — high-level voice before the turn-by-turn detail.
            // In demo mode the typewriter reveal replaces the live AI call.
            SessionSummaryView(
                summary: session.summary,
                onTriggerSummary: {
                    let persona = currentPetPersona()
                    Task { await sessionEnricher.enrich(session: session, petPersona: persona, isAutoTriggered: false) }
                },
                useTypewriter: appState.demoModeEnabled,
                hasMeaningfulWork: session.hasMeaningfulWork
            )

            // Per-turn rendering (chronological, oldest first).
            // Avatar appears only on the newest turn — older turns share the
            // pet-color thread so the page doesn't feel like the avatar
            // repeats on every entry.
            ForEach(Array(session.turns.enumerated()), id: \.element.id) { index, turn in
                turnSection(for: turn, isLast: index == session.turns.count - 1)
            }
        }
    }

    private func sessionHeaderStrip(for session: Session) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ReflectionTheme.stripText)
            Text(sessionMetaLabel(for: session))
                .font(ReflectionTheme.sans(12, weight: .medium))
                .foregroundColor(ReflectionTheme.stripText)
            // Live badge for active (non-ended) sessions
            if session.endedAt == nil && !session.turns.isEmpty {
                Text("LIVE")
                    .font(ReflectionTheme.sans(9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(ReflectionTheme.liveBadge)
                    )
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ReflectionTheme.stripBackground)
        )
    }

    @ViewBuilder
    private func turnSection(for turn: Turn, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Turn time metadata (title now lives inside the narrative bubble)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(timeDisplay(turn.startedAt))
                        .font(ReflectionTheme.sans(12))
                        .foregroundColor(ReflectionTheme.mutedText)
                    if let ended = turn.endedAt {
                        Text("·")
                            .foregroundColor(ReflectionTheme.mutedText)
                        Text("\(Int(ended.timeIntervalSince(turn.startedAt) / 60)) \(uiLanguage == .vi ? "phút" : "min")")
                            .font(ReflectionTheme.sans(12))
                            .foregroundColor(ReflectionTheme.mutedText)
                    }
                }
            }

            // Narrative chat view or loading state
            if let narrative = turn.narrative {
                NarrativeChatTurnView(narrative: narrative, showAvatar: isLast)
            } else if turn.endedAt != nil && !turn.hasWriteEvents {
                // Completed read-only turn (status checks, git log, or text-only) — show prompt quietly.
                // Only apply after the turn has ended; pending turns should show loading state
                // so they transition naturally once tool events arrive.
                Text(turn.prompt)
                    .font(ReflectionTheme.sans(13))
                    .foregroundColor(ReflectionTheme.secondaryText)
                    .italic()
                    .lineSpacing(2)
            } else {
                TurnLoadingStates(
                    state: turn.state,
                    actionCount: turn.rawEvents.count,
                    isGenerating: enricher.enrichingTurns.contains(turn.id),
                    onRetry: {
                        let persona = currentPetPersona()
                        Task { await enricher.enrich(turn: turn, petPersona: persona) }
                    }
                )
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
            Eyebrow(text: uiLanguage == .vi
                ? "CodePet v1.0 · reflection · ghi nhận âm thầm. chỉ hiện khi bạn yêu cầu."
                : "CodePet v1.0 · reflection · captured quietly. shown on request.")
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
    let summaryStore = SessionSummaryStore()
    let api = ReflectionAPIClient()
    let chatStore = SessionChatStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-chat.json")
    )
    let chatController = SessionChatController(api: api, store: chatStore)
    return ReflectionTab()
        .environmentObject(AppState())
        .environmentObject(ReflectionEventStore())
        .environmentObject(NarrativeStore())
        .environmentObject(summaryStore)
        .environmentObject(NarrativeEnricher(
            api: api,
            store: NarrativeStore(),
            language: "vi"
        ))
        .environmentObject(SessionEndStore())
        .environmentObject(SessionSummaryEnricher(
            api: api,
            store: summaryStore,
            language: "vi"
        ))
        .environmentObject(chatStore)
        .environmentObject(chatController)
        .environmentObject(DemoScriptController())
        .environmentObject(ProjectStore())
        .frame(width: 900, height: 800)
}
