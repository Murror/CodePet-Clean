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
    private var petColor: Color { pet?.color ?? PixelTheme.outline }

    private var messages: [ChatMessage] { chatStore.messages(for: session.id) }
    private var isStreaming: Bool { controller.inFlightSessionId == session.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(PixelTheme.outline).frame(height: PixelTheme.borderWidth)
            messageList
            Rectangle().fill(PixelTheme.outline).frame(height: PixelTheme.borderWidth)
            inputRow
        }
        .frame(width: 360, height: 480)
        .background(Rectangle().fill(PixelTheme.panelFill))
        .pixelBorder()
        .pixelShadow(petColor)
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
                    .background(Rectangle().fill(pet.color.opacity(0.20)))
                    .pixelBorder()
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(petName.uppercased())
                    .font(ReflectionTheme.sans(12, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(ReflectionTheme.primaryText)
                Text("Ask about this session.")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(PixelIconButtonStyle(size: 22, fill: PixelTheme.panelFill))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Rectangle().fill(petColor.opacity(0.10)))
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
                    // Sentinel: emits true to BottomVisibilityKey when this view
                    // is within 40pt of the scroll container's bottom edge.
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
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
            ? Color(white: 0.96)
            : petColor.opacity(0.18)
        HStack {
            if isUser { Spacer(minLength: 28) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(text)
                        .font(isUser
                              ? ReflectionTheme.sans(13)
                              : ReflectionTheme.serif(13.5))
                        .foregroundColor(ReflectionTheme.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if isStreaming {
                        Text("█")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(petColor)
                            .padding(.leading, 1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Rectangle().fill(bubbleFill))
                .pixelBorder(PixelTheme.outline, width: PixelTheme.borderWidth)
                .pixelShadow(PixelTheme.outline.opacity(isUser ? 0.4 : 0.5), offset: 2)
            }
            if !isUser { Spacer(minLength: 28) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - Error row

    private func errorRow(_ error: SessionChatController.ChatError) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.square.fill")
                .font(.system(size: 11))
                .foregroundColor(ReflectionTheme.moodAlert)
            Text(errorText(error))
                .font(ReflectionTheme.sans(11))
                .foregroundColor(ReflectionTheme.mutedText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Rectangle().fill(ReflectionTheme.moodAlert.opacity(0.12)))
        .pixelBorder(ReflectionTheme.moodAlert)
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
                .font(ReflectionTheme.sans(13))
                .pixelTextField()
                .onSubmit { submit() }

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(PixelButtonStyle(
                fill: canSubmit ? petColor : Color(white: 0.92),
                foreground: canSubmit ? .white : ReflectionTheme.mutedText,
                paddingH: 10,
                paddingV: 8
            ))
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Rectangle().fill(Color(white: 0.98)))
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
