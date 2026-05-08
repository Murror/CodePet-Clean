import SwiftUI

struct SessionChatPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatStore: SessionChatStore
    @EnvironmentObject var controller: SessionChatController

    let session: Session
    let onClose: () -> Void
    var onSend: (String) -> Void

    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool
    @State private var atBottom = true

    private var pet: PetCharacter? { PetCharacter.all[appState.activeChar] }
    private var petName: String { pet?.name ?? "Pet" }
    private var petColor: Color { pet?.color ?? CodepetTheme.accentPurple }

    private var messages: [ChatMessage] { chatStore.messages(for: session.id) }
    private var isStreaming: Bool { controller.inFlightSessionId == session.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            inputRow
        }
        .frame(width: 360, height: 480)
        .background(
            RoundedRectangle(cornerRadius: CodepetTheme.cardRadius, style: .continuous)
                .fill(CodepetTheme.surface)
        )
        .codepetShadow(CodepetTheme.floatingShadow)
        .onAppear { inputFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            if let pet = pet {
                Image(pet.imageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .padding(4)
                    .background(
                        Circle().fill(pet.color.opacity(0.18))
                    )
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(petName)
                    .font(CodepetTheme.body(14, weight: .semibold))
                    .foregroundColor(CodepetTheme.primaryText)
                Text("Ask about this session.")
                    .font(CodepetTheme.body(11))
                    .foregroundColor(CodepetTheme.mutedText)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(CodepetIconButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: CodepetTheme.cardRadius,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: CodepetTheme.cardRadius
                ),
                style: .continuous
            )
            .fill(petColor.opacity(0.08))
        )
    }

    // MARK: - Message list

    @ViewBuilder
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty && !isStreaming {
                        emptyGreetingBubble
                    }
                    ForEach(messages) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                    if isStreaming {
                        streamingBubble
                            .id("streaming")
                    }
                    if let error = controller.error {
                        errorRow(error)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottomSentinel")
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: BottomVisibilityKey.self,
                                    value: geo.frame(in: .named("chatScroll")).maxY
                                            <= geo.frame(in: .named("chatScroll")).size.height + 40
                                )
                            }
                        )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .coordinateSpace(name: "chatScroll")
            .onPreferenceChange(BottomVisibilityKey.self) { atBottom = $0 }
            .onChange(of: messages.count) { _ in
                if atBottom, let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: controller.streamingText) { _ in
                if atBottom {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyGreetingBubble: some View {
        bubble(role: .pet, text: greeting, isStreaming: false)
    }

    private var greeting: String {
        Locale.current.identifier.hasPrefix("vi")
            ? "Hỏi mình về phiên này nhé."
            : "Ask me about this session."
    }

    private var streamingBubble: some View {
        bubble(role: .pet, text: controller.streamingText, isStreaming: true)
    }

    private func bubble(for message: ChatMessage) -> some View {
        bubble(role: message.role, text: message.text, isStreaming: false)
    }

    @ViewBuilder
    private func bubble(role: ChatMessage.Role, text: String, isStreaming: Bool) -> some View {
        let isUser = role == .user
        let bubbleFill: Color = isUser
            ? CodepetTheme.accentPurple
            : Color(white: 0.96)
        let textColor: Color = isUser ? .white : CodepetTheme.bodyText
        HStack {
            if isUser { Spacer(minLength: 28) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(text)
                        .font(CodepetTheme.body(13.5))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if isStreaming {
                        Text("▎")
                            .font(.system(size: 13))
                            .foregroundColor(petColor)
                            .opacity(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(bubbleFill)
                )
            }
            if !isUser { Spacer(minLength: 28) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - Error row

    private func errorRow(_ error: SessionChatController.ChatError) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(CodepetTheme.accentOrange)
            Text(errorText(error))
                .font(CodepetTheme.body(11))
                .foregroundColor(CodepetTheme.mutedText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: CodepetTheme.inputRadius, style: .continuous)
                .fill(CodepetTheme.accentOrange.opacity(0.10))
        )
    }

    private func errorText(_ error: SessionChatController.ChatError) -> String {
        switch error {
        case .notSignedIn: return "Sign in to chat with your pet."
        case .rateLimited(let resetAt, _):
            if let r = resetAt {
                let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
                return "Daily limit reached. Comes back at \(f.string(from: r))."
            }
            return "You've reached today's limit."
        case .networkOrServer:
            return "Could not reach your pet — try again."
        }
    }

    // MARK: - Input row

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Type a question…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .focused($inputFocused)
                .font(CodepetTheme.body(13))
                .foregroundColor(CodepetTheme.bodyText)
                .codepetInput()
                .onSubmit { submit() }

            Button(action: submit) {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(CodepetPillButtonStyle(
                fill: canSubmit ? petColor : Color(white: 0.85),
                foreground: .white,
                paddingH: 12,
                paddingV: 9
            ))
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    private func submit() {
        guard canSubmit else { return }
        let text = draft
        draft = ""
        onSend(text)
    }
}

// MARK: - Preference key for bottom-proximity auto-scroll guard

private struct BottomVisibilityKey: PreferenceKey {
    static var defaultValue: Bool = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
