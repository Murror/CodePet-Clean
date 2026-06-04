import SwiftUI

/// In-app practice space for a skill-card exercise (SkillChallenge).
///
/// PRACTICE MODEL: the user does the directing. They read the goal, **write the
/// prompt themselves** (graded live), then run it against a private practice
/// SANDBOX — never their real project (see PracticeSandbox). Afterwards they
/// review the diff and confirm it met the goal. Claude does the mechanical edit;
/// the skill being practiced is writing the instruction and judging the result.
///
/// Reuses `CodeExecutionView` (defined in RunForRealSection.swift).
struct ExerciseWorkspaceView: View {
    let challenge: SkillChallenge
    let character: PetCharacter

    @StateObject private var runner = ClaudeCodeRunner()
    @State private var promptText = ""
    @State private var sandboxPath = ""
    @State private var sandboxError: String? = nil
    @State private var showFile = false

    private var primaryFile: String { PracticeSandbox.primaryFile(forSkill: challenge.skillId) }

    private var grade: PracticePromptGrader.Grade? {
        let words = promptText.split { $0 == " " || $0 == "\n" }.count
        guard words >= 6 else { return nil }
        return PracticePromptGrader.grade(prompt: promptText, goal: challenge.acceptanceCriteria)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    exerciseHeader
                    sandboxRow
                    filePreview
                    promptCard
                    if let g = grade { gradeBanner(g) }
                    runControls

                    if !runner.events.isEmpty {
                        CodeExecutionView(events: runner.events, accent: character.color)
                    }
                    if let coach = coachLine {
                        coachBubble(coach)
                    }
                    if let err = sandboxError {
                        banner(err, bg: Color(hex: "#F7E3DE"), fg: Color(hex: "#8A3324"))
                    }
                    if case .failed(let reason) = runner.state {
                        banner(reason, bg: Color(hex: "#F7E3DE"), fg: Color(hex: "#8A3324"))
                    }
                    if case .finished = runner.state {
                        reviewStep
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
        .onAppear { prepareSandbox() }
        .onDisappear { runner.cancel() }
    }

    // MARK: - Header

    private var exerciseHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(challenge.title)
                    .font(.pixelSystem(size: 14, weight: .bold))
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

    // MARK: - Sandbox notice + reset

    private var sandboxRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#3FA66A"))
            Text("Practice copy — your real projects are never touched")
                .font(.pixelSystem(size: 9))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
            Spacer()
            Button("Reset") { resetSandbox() }
                .font(.pixelSystem(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: "#2D2B26"))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color(hex: "#F0F0EC")).cornerRadius(6)
                .buttonStyle(.plain)
                .disabled(runner.isRunning)
        }
    }

    // MARK: - Sandbox file preview

    private var filePreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { withAnimation { showFile.toggle() } }) {
                HStack(spacing: 5) {
                    Image(systemName: showFile ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text(primaryFile)
                        .font(.pixelSystem(size: 10, design: .monospaced))
                }
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
            }
            .buttonStyle(.plain)

            if showFile {
                ScrollView {
                    Text(PracticeSandbox.currentContents(of: primaryFile) ?? "—")
                        .font(.pixelSystem(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                }
                .frame(maxHeight: 180)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#2D2B26").opacity(0.05)))
            }
        }
    }

    // MARK: - Prompt (the user writes this)

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("YOUR PROMPT")
                    .font(.pixelSystem(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.45))
                Text("— you write this, then run it")
                    .font(.pixelSystem(size: 8))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.35))
            }
            ZStack(alignment: .topLeading) {
                if promptText.isEmpty {
                    Text("Tell Claude Code exactly what to change in \(primaryFile)…")
                        .font(.pixelSystem(size: 11))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.3))
                        .padding(.horizontal, 11).padding(.vertical, 12)
                }
                TextEditor(text: $promptText)
                    .font(.pixelSystem(size: 11))
                    .frame(minHeight: 72, maxHeight: 130)
                    .padding(6)
                    .scrollContentBackground(.hidden)
                    .disabled(runner.isRunning)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(character.color.opacity(0.08)))
        }
    }

    private func gradeBanner(_ g: PracticePromptGrader.Grade) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(g.letter)
                .font(.pixelSystem(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(gradeColor(g.score))
            VStack(alignment: .leading, spacing: 2) {
                Text("Prompt score: \(g.score)%")
                    .font(.pixelSystem(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                if let tip = g.tips.first {
                    Text("Tip: \(tip)")
                        .font(.pixelSystem(size: 9))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                } else if let s = g.strengths.first {
                    Text("✓ \(s)")
                        .font(.pixelSystem(size: 9))
                        .foregroundColor(Color(hex: "#3FA66A"))
                }
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(gradeColor(g.score).opacity(0.10)))
    }

    private func gradeColor(_ score: Int) -> Color {
        switch score {
        case 75...: return Color(hex: "#3FA66A")
        case 50..<75: return Color(hex: "#D4960A")
        default: return Color(hex: "#E06050")
        }
    }

    // MARK: - Run controls

    private var runControls: some View {
        HStack(spacing: 10) {
            if runner.isRunning {
                Button(action: { runner.cancel() }) {
                    Text("Stop")
                        .font(.pixelSystem(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Color(hex: "#C7563F")).cornerRadius(8)
                }
                .buttonStyle(.plain)
                HStack(spacing: 5) {
                    ProgressView().controlSize(.small)
                    Text("\(character.name) is working…")
                        .font(.pixelSystem(size: 10))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                }
            } else {
                Button(action: startRun) {
                    Text("▶  Run my prompt")
                        .font(.pixelSystem(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(canRun ? character.color : Color(hex: "#D0D0CC"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canRun)
                if promptText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Write your prompt first")
                        .font(.pixelSystem(size: 9))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.45))
                }
            }
        }
    }

    private var canRun: Bool {
        !sandboxPath.isEmpty && !promptText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func prepareSandbox() {
        do { sandboxPath = try PracticeSandbox.prepare() }
        catch { sandboxError = "Couldn't set up the practice sandbox: \(error.localizedDescription)" }
    }

    private func resetSandbox() {
        do { sandboxPath = try PracticeSandbox.reset(); SoundManager.shared.playTap() }
        catch { sandboxError = "Couldn't reset the sandbox: \(error.localizedDescription)" }
    }

    private func startRun() {
        SoundManager.shared.playTap()
        runner.run(prompt: promptText, projectDir: sandboxPath)
    }

    // MARK: - Coaching (rule-based — no model calls)

    private var coachLine: String? {
        switch runner.state {
        case .idle:
            return "Read the goal, peek at \(primaryFile) if you like, then write the prompt YOU think will get it done. I'll run it on the practice copy."
        case .running:
            if let last = runner.events.last(where: { $0.kind == .toolUse }) {
                switch last.toolName {
                case "Write":     return "It made a new file — that's the structure your prompt asked for."
                case "Edit", "MultiEdit": return "Editing in place to wire things together without breaking them."
                case "Bash":      return "Running a command to check its work."
                case "Read", "Glob", "Grep": return "Exploring the code before changing it — measure twice, cut once."
                default:          return "Watch each step — was this what your prompt intended?"
                }
            }
            return "Reading the project to find where your change belongs."
        case .finished:
            return nil // review step takes over
        case .failed:
            return nil
        }
    }

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

    // MARK: - Review (the second half of the practice)

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                CharacterImage(character.id, size: 24)
                Text("Your turn to judge it")
                    .font(.pixelSystem(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))
            }
            Text("Did it meet the goal — \(challenge.acceptanceCriteria)? Open \(primaryFile) above to see the result, and ask yourself *why* this change helps.")
                .font(.pixelSystem(size: 10))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Reset & try again") { resetSandbox(); runner.cancel() }
                    .font(.pixelSystem(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "#F0F0EC")).cornerRadius(8)
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#3FA66A").opacity(0.12)))
    }

    private func banner(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.pixelSystem(size: 10))
            .foregroundColor(fg)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(bg))
    }
}
