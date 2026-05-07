import SwiftUI

struct WelcomeSessionView: View {
    @EnvironmentObject var appState: AppState

    @State private var projectBrief: String = ""
    @State private var savedConfirmation: Date? = nil

    private var pet: PetCharacter? { PetCharacter.all[appState.activeChar] }
    private var petName: String { pet?.name ?? "Pet" }

    private static let installCommand = "bash scripts/install-reflection-hooks.sh"
    private static let settingsSnippet = """
    "hooks": {
      "UserPromptSubmit": [{
        "hooks": [{ "type": "command", "command": "~/.codepet/hooks/log-prompt.sh" }]
      }],
      "PostToolUse": [{
        "matcher": "*",
        "hooks": [{ "type": "command", "command": "~/.codepet/hooks/log-tool.sh" }]
      }],
      "Stop": [{
        "hooks": [{ "type": "command", "command": "~/.codepet/hooks/log-summary.sh" }]
      }],
      "SessionEnd": [{
        "hooks": [{ "type": "command", "command": "~/.codepet/hooks/log-session-end.sh" }]
      }]
    }
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            heroBanner
            stepCard(
                number: "1",
                title: "Install Claude Code hooks",
                description: "Run this once in Terminal — it sets up four scripts that capture your prompts, tools, and session boundaries.",
                code: Self.installCommand
            )
            stepCard(
                number: "2",
                title: "Paste the hook config",
                description: "Open ~/.claude/settings.json and merge this snippet under the top-level \"hooks\" key.",
                code: Self.settingsSnippet
            )
            stepCard(
                number: "3",
                title: "(Optional) Connect MCP",
                description: "If you use the Model Context Protocol, add CodePet's MCP server so Claude can read your project context. Run:",
                code: "claude mcp add codepet -- npx -y @murror/codepet-mcp"
            )
            briefCard
            footer
        }
        .onAppear { loadSavedBrief() }
    }

    private var heroBanner: some View {
        HStack(alignment: .center, spacing: 16) {
            if let pet = pet {
                Image(pet.imageName)
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(pet.color.opacity(0.18)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(pet.color.opacity(0.55), lineWidth: 2))
                    .shadow(color: pet.color.opacity(0.4), radius: 10, y: 4)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Hi, I'm \(petName) \u{1F44B}")
                    .font(ReflectionTheme.serif(24, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text("Let's get your reflection journal connected. Three quick steps.")
                    .font(ReflectionTheme.sans(13))
                    .foregroundColor(ReflectionTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ReflectionTheme.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ReflectionTheme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private func stepCard(number: String, title: String, description: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(number)
                    .font(ReflectionTheme.serif(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(ReflectionTheme.accent))
                Text(title)
                    .font(ReflectionTheme.serif(17, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Spacer()
            }
            Text(description)
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            codeBlock(code)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ReflectionTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ReflectionTheme.borderLight, lineWidth: 1)
        )
    }

    private func codeBlock(_ code: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(code)
                .font(ReflectionTheme.mono(11))
                .foregroundColor(ReflectionTheme.primaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            CopyButton(text: code)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0xF5 / 255.0, green: 0xF3 / 255.0, blue: 0xFA / 255.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ReflectionTheme.borderLight, lineWidth: 1)
        )
    }

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ReflectionTheme.accent)
                    .frame(width: 26, height: 26)
                Text("Tell me about your project")
                    .font(ReflectionTheme.serif(17, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Spacer()
            }
            Text("A short brief — what you're building, who it's for, what stage you're at. I'll use this as context when summarizing your sessions.")
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $projectBrief)
                .font(ReflectionTheme.serif(13))
                .foregroundColor(ReflectionTheme.primaryText)
                .padding(8)
                .frame(minHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(ReflectionTheme.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(ReflectionTheme.borderLight, lineWidth: 1)
                )

            HStack(spacing: 10) {
                Button(action: saveBrief) {
                    Text("Save brief")
                        .font(ReflectionTheme.sans(12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(ReflectionTheme.accent))
                }
                .buttonStyle(.plain)
                .disabled(projectBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(projectBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)

                if let until = savedConfirmation, until > Date() {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ReflectionTheme.moodCalm)
                        Text("Saved")
                            .font(ReflectionTheme.sans(11, weight: .medium))
                            .foregroundColor(ReflectionTheme.secondaryText)
                    }
                    .transition(.opacity)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ReflectionTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ReflectionTheme.borderLight, lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(ReflectionTheme.mutedText)
            Text("After Step 1 + 2, restart Claude Code. Your turns will start landing here automatically.")
                .font(ReflectionTheme.sans(12))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Persistence

    private static let briefKey = "cp_user_project_brief"

    private func loadSavedBrief() {
        projectBrief = UserDefaults.standard.string(forKey: Self.briefKey) ?? ""
    }

    private func saveBrief() {
        UserDefaults.standard.set(projectBrief, forKey: Self.briefKey)
        withAnimation(.easeInOut(duration: 0.2)) {
            savedConfirmation = Date().addingTimeInterval(2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if let until = savedConfirmation, until <= Date() {
                    savedConfirmation = nil
                }
            }
        }
    }
}

private struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button(action: copy) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(copied ? ReflectionTheme.moodCalm : ReflectionTheme.mutedText)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ReflectionTheme.background)
                )
        }
        .buttonStyle(.plain)
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        withAnimation(.easeInOut(duration: 0.18)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.18)) { copied = false }
        }
    }
}
