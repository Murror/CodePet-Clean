import SwiftUI

struct TurnLoadingStates: View {
    let state: TurnState
    var actionCount: Int = 0
    var onRetry: () -> Void = {}
    var onSignIn: () -> Void = {}

    var body: some View {
        switch state {
        case .pending:
            pendingCard

        case .summarizing:
            PixelCard {
                VStack(alignment: .leading, spacing: 14) {
                    skeletonLine(width: 0.85)
                    skeletonLine(width: 0.7)
                    skeletonLine(width: 0.6)
                    Text("Summarizing the story…")
                        .font(.pixelSystem(size: 11))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .ready:
            EmptyView()  // body shown by NarrativeChatTurnView

        case .pendingOrphan:
            stateCard(
                title: "Session left unfinished",
                detail: "This turn didn't close normally — Claude Code may have been closed mid-way.",
                fill: Color(hex: "#FCEBA8")
            )

        case .failed(let reason):
            failedView(reason: reason)
        }
    }

    private var pendingCard: some View {
        PixelCard(fill: Color(hex: "#F5E8C7")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Working")
                        .font(.pixelSystem(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26"))
                    PulsingDots()
                }
                Text(pendingDetail)
                    .font(CodepetTheme.body(13))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pendingDetail: String {
        switch actionCount {
        case 0:
            return "Watching… Claude may still be thinking, or only writing text. The story arrives when this turn closes."
        case 1:
            return "1 action so far. The story will appear once Claude is done."
        default:
            return "\(actionCount) actions so far. The story will appear once Claude is done."
        }
    }

    private func stateCard(title: String, detail: String, fill: Color) -> some View {
        PixelCard(fill: fill) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.pixelSystem(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                Text(detail)
                    .font(CodepetTheme.body(13))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func skeletonLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color(hex: "#2D2B26").opacity(0.15))
            .frame(maxWidth: .infinity)
            .frame(height: 12)
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

        PixelCard(fill: Color(hex: "#A8D8D4")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.pixelSystem(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#B6850A"))
                    Text(title)
                        .font(.pixelSystem(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26"))
                }
                Text(detail)
                    .font(CodepetTheme.body(13))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: action) {
                    Text(reason == .auth ? "Sign in" : "Try again")
                }
                .buttonStyle(PixelButtonStyle(
                    fill: Color(hex: "#2D2B26"),
                    font: .pixelSystem(size: 12, weight: .semibold)
                ))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Three dots that fade in/out in a wave — used in the .pending card so the
/// user sees the turn is being watched live, not stuck.
private struct PulsingDots: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Text("●")
                    .font(.pixelSystem(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .opacity(phase == i ? 1.0 : 0.25)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = (phase + 1) % 3
            }
        }
    }
}
