import SwiftUI

struct TurnLoadingStates: View {
    let state: TurnState
    var onRetry: () -> Void = {}
    var onSignIn: () -> Void = {}

    var body: some View {
        switch state {
        case .pending:
            stateRow(
                title: "Working…",
                detail: "This turn isn't finished yet. The story will appear once Claude is done."
            )

        case .summarizing:
            VStack(alignment: .leading, spacing: 14) {
                skeletonLine(width: 0.85)
                skeletonLine(width: 0.7)
                skeletonLine(width: 0.6)
                Text("Summarizing the story…")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

        case .ready:
            EmptyView()  // body shown by NarrativeChatTurnView

        case .pendingOrphan:
            stateRow(
                title: "Session left unfinished",
                detail: "This turn didn't close normally — Claude Code may have been closed mid-way."
            )

        case .failed(let reason):
            failedView(reason: reason)
        }
    }

    private func stateRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ReflectionTheme.serif(16, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
            Text(detail)
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func skeletonLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(ReflectionTheme.borderLight.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 14)
            .scaleEffect(x: width, y: 1, anchor: .leading)
    }

    @ViewBuilder
    private func failedView(reason: FailureReason) -> some View {
        let (title, detail, action): (String, String, () -> Void) = {
            switch reason {
            case .network:
                return ("Couldn't summarize the story",
                        "Network seems to be acting up. You can try again.",
                        onRetry)
            case .quota:
                return ("Daily limit reached",
                        "You've hit 50 summaries today. Resets at 00:00 UTC.",
                        onRetry)
            case .auth:
                return ("Sign in again",
                        "Your sign-in has expired.",
                        onSignIn)
            case .badResponse:
                return ("Summary error",
                        "AI returned unexpected data. You can try again.",
                        onRetry)
            case .unknown:
                return ("Couldn't summarize",
                        "Something went wrong. You can try again.",
                        onRetry)
            }
        }()

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ReflectionTheme.moodAlert)
                Text(title)
                    .font(ReflectionTheme.serif(16, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
            }
            Text(detail)
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(reason == .auth ? "Sign in" : "Try again")
                    .font(ReflectionTheme.sans(12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(ReflectionTheme.accent))
            }
            .buttonStyle(.plain)
        }
    }
}
