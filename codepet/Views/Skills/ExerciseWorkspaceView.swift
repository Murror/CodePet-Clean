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
                    promptCard
                    runControls

                    if !runner.events.isEmpty {
                        CodeExecutionView(events: runner.events, characterColor: character.color)
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
        .onDisappear { runner.cancel() }
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
