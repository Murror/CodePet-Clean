import SwiftUI
import AppKit

/// In-app practice space. Replaces the "open your terminal and paste this"
/// handoff: the user runs the exercise prompt against their project right here,
/// driven by their local `claude` (see ClaudeCodeRunner), with the pet coaching
/// between steps. Skill completion is still detected by the existing
/// NarrativeEnricher pipeline from the same tool events.
struct ExerciseWorkspaceView: View {
    let challenge: SkillChallenge
    let character: PetCharacter

    @EnvironmentObject private var hookInstaller: HookInstaller
    @StateObject private var runner = ClaudeCodeRunner()
    @State private var promptText: String
    @AppStorage("cp_last_project_dir") private var lastProjectDir: String = ""

    init(challenge: SkillChallenge, character: PetCharacter) {
        self.challenge = challenge
        self.character = character
        _promptText = State(initialValue: challenge.description)
    }

    private var projectDir: String {
        if let p = challenge.projectPath, !p.isEmpty { return p }
        return lastProjectDir
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    exerciseHeader
                    projectRow
                    hooksNotice
                    promptCard
                    runControls

                    if !runner.events.isEmpty {
                        CodeExecutionView(events: runner.events, characterColor: character.color)
                    }

                    if !runner.fileDiffs.isEmpty {
                        FileDiffView(diffs: runner.fileDiffs, accent: character.color)
                    }

                    if let coach = ExercisePetCoach.line(for: runner, challenge: challenge, petName: character.name) {
                        coachBubble(coach)
                    }

                    if case .failed(let reason) = runner.state {
                        errorBanner(reason)
                    }

                    if case .finished = runner.state {
                        finishedFooter
                    }

                    Color.clear.frame(height: 1).id("ex_bottom")
                }
                .padding(16)
            }
            .onChange(of: runner.events.count) { _ in
                withAnimation { proxy.scrollTo("ex_bottom", anchor: .bottom) }
            }
        }
        .background(character.color.opacity(0.05))
        .onAppear { hookInstaller.checkInstallation() }
        .onDisappear { runner.cancel() }
    }

    // MARK: - Reflection hooks notice (auto-completion depends on them)

    /// This view's skill auto-completion relies on the reflection hooks: after the
    /// run, NarrativeEnricher reads the captured session to mark the exercise done
    /// (see `finishedFooter`). If the hooks aren't installed that never fires, so
    /// surface the one-time setup here while it's missing. Hidden once installed.
    @ViewBuilder
    private var hooksNotice: some View {
        switch hookInstaller.status {
        case .installed:
            EmptyView()

        case .notInstalled:
            hooksCard(icon: "link.badge.plus", title: "Set up auto-complete") {
                Text("This exercise marks complete automatically once Codepet sees the skill in your coding session — but that needs the reflection hooks installed. One-time setup.")
                    .font(.pixelSystem(size: 10))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                hooksButton(icon: "doc.on.clipboard", title: "Copy setup command",
                            fill: character.color) { hookInstaller.install() }
            }

        case .installing:
            hooksCard(icon: "checkmark.circle.fill", title: "Command copied") {
                Text("Open Terminal → paste (⌘V) → press Enter. Then tap “I've done it”.")
                    .font(.pixelSystem(size: 10))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    hooksButton(icon: "checkmark", title: "I've done it",
                                fill: Color(hex: "#3FA66A")) { hookInstaller.verifyInstallation() }
                    Button("Copy again") { hookInstaller.install() }
                        .font(.pixelSystem(size: 10, weight: .semibold))
                        .foregroundColor(character.color)
                        .buttonStyle(.plain)
                }
            }

        case .failed(let error):
            hooksCard(icon: "exclamationmark.triangle.fill", title: "Setup failed") {
                Text(error)
                    .font(.pixelSystem(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#8A3324"))
                    .fixedSize(horizontal: false, vertical: true)
                hooksButton(icon: "arrow.clockwise", title: "Try again",
                            fill: character.color) { hookInstaller.install() }
            }
        }
    }

    @ViewBuilder
    private func hooksCard<Content: View>(icon: String, title: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(character.color)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.pixelSystem(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                content()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(character.color.opacity(0.08)))
    }

    private func hooksButton(icon: String, title: String, fill: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.pixelSystem(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(fill).cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(challenge.title)
                    .font(.pixelSystem(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                Spacer()
                difficultyBadge
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("GOAL")
                    .font(.pixelSystem(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.45))
                Text(challenge.acceptanceCriteria)
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(character.color.opacity(0.10)))
        }
    }

    private var difficultyBadge: some View {
        let (label, color): (String, Color) = {
            switch challenge.difficulty {
            case .starter:  return ("STARTER", Color(hex: "#3FA66A"))
            case .practice: return ("PRACTICE", Color(hex: "#7B6BD8"))
            case .stretch:  return ("STRETCH", Color(hex: "#E08A3C"))
            }
        }()
        return Text(label)
            .font(.pixelSystem(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(color))
    }

    // MARK: - Project folder

    private var projectRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
            Text(projectDir.isEmpty ? "No project folder selected" : (projectDir as NSString).abbreviatingWithTildeInPath)
                .font(.pixelSystem(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(projectDir.isEmpty ? 0.4 : 0.7))
                .lineLimit(1).truncationMode(.head)
            Spacer()
            Button(projectDir.isEmpty ? "Choose…" : "Change") { chooseProjectFolder() }
                .buttonStyle(PixelButtonStyle(
                    fill: Color(hex: "#F0F0EC"), foreground: Color(hex: "#2D2B26"),
                    paddingH: 9, paddingV: 4, blockSize: 2, steps: 2,
                    borderWidth: 2, shadowOffset: 2, font: .pixelSystem(size: 9, weight: .medium)))
        }
    }

    private func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Project"
        if panel.runModal() == .OK, let url = panel.url {
            lastProjectDir = url.path
        }
    }

    // MARK: - Prompt

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROMPT FOR CLAUDE CODE")
                .font(.pixelSystem(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.45))
            TextEditor(text: $promptText)
                .font(.pixelSystem(size: 11))
                .frame(minHeight: 64, maxHeight: 120)
                .padding(6)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 10).fill(character.color.opacity(0.08)))
                .disabled(runner.isRunning)
        }
    }

    // MARK: - Run controls

    private var runControls: some View {
        HStack(spacing: 10) {
            if runner.isRunning {
                Button("Stop") { runner.cancel() }
                    .buttonStyle(PixelButtonStyle(
                        fill: Color(hex: "#C7563F"), foreground: .white,
                        paddingH: 16, paddingV: 8, blockSize: 2, steps: 2,
                        borderWidth: 2, shadowOffset: 3, font: .pixelSystem(size: 12, weight: .bold)))
                HStack(spacing: 4) {
                    ProgressView().controlSize(.small)
                    Text("\(character.name) is working…")
                        .font(.pixelSystem(size: 10))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                }
            } else {
                Button("▶  Run in Codepet") { startRun() }
                    .buttonStyle(PixelButtonStyle(
                        fill: projectDir.isEmpty ? Color(hex: "#D0D0CC") : character.color,
                        foreground: .white, paddingH: 16, paddingV: 8, blockSize: 2, steps: 2,
                        borderWidth: 2, shadowOffset: 3, font: .pixelSystem(size: 12, weight: .bold)))
                    .disabled(projectDir.isEmpty || promptText.trimmingCharacters(in: .whitespaces).isEmpty)
                if projectDir.isEmpty {
                    Text("Pick your project folder first")
                        .font(.pixelSystem(size: 9))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.45))
                }
            }
        }
    }

    private func startRun() {
        SoundManager.shared.playTap()
        runner.run(prompt: promptText, projectDir: projectDir)
    }

    // MARK: - Coaching / status

    private func coachBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            CharacterImage(character.id, size: 26)
            Text(text)
                .font(.pixelSystem(size: 11))
                .foregroundColor(Color(hex: "#2D2B26"))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(character.color.opacity(0.15)))
        }
    }

    private func errorBanner(_ reason: String) -> some View {
        Text(reason)
            .font(.pixelSystem(size: 10))
            .foregroundColor(Color(hex: "#8A3324"))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#F7E3DE")))
    }

    private var finishedFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Run finished. Codepet is checking your session for the skill — watch the Tips tab; this exercise marks complete automatically when it's detected.")
                .font(.pixelSystem(size: 10))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#3FA66A").opacity(0.14)))
    }
}

// =============================================================================
// MARK: - CodeExecutionView — live feed of what Claude Code did
// =============================================================================

struct CodeExecutionView: View {
    let events: [ClaudeCodeRunner.StreamEvent]
    let characterColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT CLAUDE CODE DID")
                .font(.pixelSystem(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.45))
            VStack(alignment: .leading, spacing: 5) {
                ForEach(events) { event in
                    row(for: event)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#2D2B26").opacity(0.05)))
        }
    }

    @ViewBuilder
    private func row(for event: ClaudeCodeRunner.StreamEvent) -> some View {
        switch event.kind {
        case .assistantText:
            Text(event.text)
                .font(.pixelSystem(size: 11))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        case .toolUse:
            HStack(spacing: 6) {
                Image(systemName: icon(for: event.toolName))
                    .font(.system(size: 10))
                    .foregroundColor(characterColor)
                Text(event.text)
                    .font(.pixelSystem(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.8))
                    .lineLimit(2)
            }
        case .toolResult:
            Text(event.text)
                .font(.pixelSystem(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                .lineLimit(3)
                .padding(.leading, 16)
        case .result:
            Text(event.text)
                .font(.pixelSystem(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
        case .system:
            EmptyView()
        }
    }

    private func icon(for tool: String?) -> String {
        switch tool {
        case "Write": return "doc.badge.plus"
        case "Edit", "MultiEdit": return "pencil"
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Glob", "Grep": return "magnifyingglass"
        default: return "wrench.and.screwdriver"
        }
    }
}

// =============================================================================
// MARK: - FileDiffView — real before/after for each changed file
// =============================================================================

/// Shows the actual line-level changes Claude made to each file this run, built
/// from a pre-run snapshot diffed against what's now on disk (see
/// ClaudeCodeRunner.computeDiffs). One collapsible block per file.
struct FileDiffView: View {
    let diffs: [ClaudeCodeRunner.FileDiff]
    let accent: Color

    @State private var collapsed: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BEFORE → AFTER")
                .font(.pixelSystem(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.45))
            ForEach(diffs) { diff in
                diffBlock(diff)
            }
        }
    }

    @ViewBuilder
    private func diffBlock(_ diff: ClaudeCodeRunner.FileDiff) -> some View {
        let isOpen = !collapsed.contains(diff.id)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    if isOpen { collapsed.insert(diff.id) } else { collapsed.remove(diff.id) }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                    Image(systemName: diff.isNewFile ? "doc.badge.plus" : "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(accent)
                    Text(diff.fileName)
                        .font(.pixelSystem(size: 10, design: .monospaced))
                    if diff.isNewFile {
                        Text("NEW")
                            .font(.pixelSystem(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#3FA66A")))
                    }
                    Spacer()
                    Text(changeSummary(diff))
                        .font(.pixelSystem(size: 8, design: .monospaced))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                }
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.75))
                .padding(.vertical, 6).padding(.horizontal, 9)
            }
            .buttonStyle(.plain)

            if isOpen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(diff.lines) { line in
                            diffLine(line)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#2D2B26").opacity(0.05)))
    }

    @ViewBuilder
    private func diffLine(_ line: ClaudeCodeRunner.FileDiff.Line) -> some View {
        let (bg, fg, gutter): (Color, Color, String) = {
            switch line.kind {
            case .added:   return (Color(hex: "#3FA66A").opacity(0.16), Color(hex: "#1E6B40"), "+")
            case .removed: return (Color(hex: "#E06050").opacity(0.16), Color(hex: "#8A3324"), "−")
            case .context: return (.clear, Color(hex: "#2D2B26").opacity(0.55), " ")
            }
        }()
        HStack(alignment: .top, spacing: 6) {
            Text(gutter)
                .font(.pixelSystem(size: 10, design: .monospaced))
                .foregroundColor(fg.opacity(0.7))
                .frame(width: 9, alignment: .center)
            Text(line.text.isEmpty ? " " : line.text)
                .font(.pixelSystem(size: 10, design: .monospaced))
                .foregroundColor(fg)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 9).padding(.vertical, 1)
        .background(bg)
    }

    private func changeSummary(_ diff: ClaudeCodeRunner.FileDiff) -> String {
        let added = diff.lines.filter { $0.kind == .added }.count
        let removed = diff.lines.filter { $0.kind == .removed }.count
        return "+\(added) −\(removed)"
    }
}

// =============================================================================
// MARK: - ExercisePetCoach — deterministic coaching (no extra model calls)
// =============================================================================

/// Derives a single contextual coaching line from the runner's current events.
/// Intentionally rule-based so it costs zero tokens — the expensive work already
/// happened in the user's own claude run.
enum ExercisePetCoach {
    static func line(for runner: ClaudeCodeRunner,
                     challenge: SkillChallenge,
                     petName: String) -> String? {
        switch runner.state {
        case .idle:
            return "When you're ready, hit Run. I'll watch what Claude Code does and explain the why as it goes."
        case .running:
            // Latest meaningful tool action drives the commentary.
            if let last = runner.events.last(where: { $0.kind == .toolUse }) {
                return coachForTool(last, skillId: challenge.skillId)
            }
            return "Reading your project first — that's how it figures out where to make changes."
        case .finished:
            return "Done! The goal was: \(challenge.acceptanceCriteria) Skim the changes above and ask yourself *why* each one helps — that understanding is the real skill."
        case .failed:
            return nil // error banner already explains it
        }
    }

    private static func coachForTool(_ event: ClaudeCodeRunner.StreamEvent, skillId: String) -> String {
        switch event.toolName {
        case "Write":
            return "See how it created a new file? Pulling code into its own file is exactly what \(skillId.replacingOccurrences(of: "_", with: " ")) is about."
        case "Edit", "MultiEdit":
            return "It's editing in place — wiring the old code to use the new structure so nothing breaks."
        case "Bash":
            return "Running a command to check its work. Watching it verify is a habit worth copying."
        case "Read", "Glob", "Grep":
            return "It's exploring your code before changing anything — measure twice, cut once."
        default:
            return "Follow along with each step — the learning is in the why, not the typing."
        }
    }
}
