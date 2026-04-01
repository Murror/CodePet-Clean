import SwiftUI

struct CompanionPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var chatInput = ""
    @State private var showSwitchSheet = false
    var onClose: (() -> Void)? = nil

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        VStack(spacing: 0) {
            // Character Header
            VStack(spacing: 12) {
                HStack {
                    // Character info
                    HStack(spacing: 10) {
                        CharacterImage(character.id, size: 44)
                            .charIdle(character.id)
                            .petBreathing()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(character.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                            Text(character.badge)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                        }
                    }

                    Spacer()

                    Button("Switch") {
                        showSwitchSheet = true
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#F0F0EC"))
                    )
                    .buttonStyle(.plain)

                    Button(action: { onClose?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#6BCB77"))
                        .frame(width: 6, height: 6)
                    Text(statusMessage)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.white)

            Divider()

            // Chat content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Skill suggestion bubble
                    CompanionBubble(
                        character: character,
                        message: skillSuggestion
                    )

                    // Quick action buttons
                    QuickActionsGrid()
                }
                .padding(16)
            }
            .background(Color(hex: "#FAFAF7"))

            Spacer()

            // Chat input
            Divider()
            HStack(spacing: 8) {
                TextField("Ask \(character.name)...", text: $chatInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#F5F5F2"))
                    )

                Button(action: {}) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(chatInput.isEmpty ? Color(hex: "#D0D0CC") : character.color)
                }
                .buttonStyle(.plain)
                .disabled(chatInput.isEmpty)
            }
            .padding(12)
            .background(Color.white)
        }
        .background(Color.white)
        .sheet(isPresented: $showSwitchSheet) {
            CharacterSwitchSheet(onSelect: { charId in
                appState.activeChar = charId
                showSwitchSheet = false
                SoundManager.shared.playTap()
            })
        }
    }

    private var statusMessage: String {
        let phrases: [String: String] = [
            "byte": "Scanning for bugs...",
            "nova": "Ready to ship something",
            "crash": "Let's break things!",
            "luna": "Dreaming up designs...",
            "sage": "Meditating on architecture",
            "glitch": "Hacking the mainframe...",
            "zero": "...",
            "null": "Deleting things randomly"
        ]
        return phrases[appState.activeChar] ?? "Online"
    }

    private var skillSuggestion: String {
        let completed = appState.completedLessons
        if completed.isEmpty {
            return "Start with Prompt Clarity — it's the foundation for everything else. Trust me, once you nail this, everything clicks."
        }

        // Suggest based on strongest skills
        let count = completed.count
        if count < 4 {
            let remaining = GameData.skillTiers[0].skills.filter { !completed.contains($0.id) }
            if let next = remaining.first {
                return "Your strongest skills are \(completed.map { skillName(for: $0) }.joined(separator: " and ")). I'd suggest \(next.name) next — it'll reduce your most common errors."
            }
        }

        if count < 8 {
            return "You're making great progress through Tier \(appState.currentTier)! Keep going — the next kingdom awaits."
        }

        return "You've come so far! Let's tackle the advanced skills and really level up your AI workflow."
    }

    private func skillName(for id: String) -> String {
        for tier in GameData.skillTiers {
            if let skill = tier.skills.first(where: { $0.id == id }) {
                return skill.name
            }
        }
        return id
    }
}

// MARK: - Companion Chat Bubble

struct CompanionBubble: View {
    let character: PetCharacter
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CharacterImage(character.id, size: 24)
                .petBreathing()

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#2D2B26"))
                .lineSpacing(4)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(character.color.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(character.color.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Quick Actions

struct QuickActionsGrid: View {
    let actions = [
        "What should I build today?",
        "I'm scared to ship",
        "How do I stop overthinking?",
        "Let's do a speed build"
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(actions.chunked(into: 2).enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 8) {
                    ForEach(pair, id: \.self) { action in
                        Button(action: {}) {
                            Text(action)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(hex: "#E8E6E0"), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Character Switch Sheet

struct CharacterSwitchSheet: View {
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Switch Companion")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#2D2B26"))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(PetCharacter.starters, id: \.self) { charId in
                    if let char = PetCharacter.all[charId] {
                        Button(action: { onSelect(charId) }) {
                            VStack(spacing: 6) {
                                CharacterImage(charId, size: 48)
                                    .charIdle(charId)

                                Text(char.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(char.color)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 200)
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    CompanionPanelView()
        .environmentObject(AppState())
        .frame(width: 280, height: 600)
}
