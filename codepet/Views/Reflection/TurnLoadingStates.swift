import SwiftUI

struct TurnLoadingStates: View {
    let state: TurnState
    var onRetry: () -> Void = {}
    var onSignIn: () -> Void = {}

    var body: some View {
        switch state {
        case .pending:
            stateRow(
                title: "Đang làm…",
                detail: "Lượt này chưa kết thúc. Câu chuyện sẽ xuất hiện khi Claude xong."
            )

        case .summarizing:
            VStack(alignment: .leading, spacing: 14) {
                skeletonLine(width: 0.85)
                skeletonLine(width: 0.7)
                skeletonLine(width: 0.6)
                Text("Đang tóm tắt câu chuyện…")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

        case .ready:
            EmptyView()  // body shown by NarrativeBodyView

        case .pendingOrphan:
            stateRow(
                title: "Phiên chưa hoàn thành",
                detail: "Lượt này không kết thúc bình thường — có thể Claude Code bị đóng giữa chừng."
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
                return ("Không tóm tắt được câu chuyện",
                        "Có vẻ mạng đang trục trặc. Bạn có thể thử lại.",
                        onRetry)
            case .quota:
                return ("Hết hạn ngạch hôm nay",
                        "Bạn đã đạt 50 câu chuyện hôm nay. Reset sau 00:00 UTC.",
                        onRetry)
            case .auth:
                return ("Cần đăng nhập lại",
                        "Phiên đăng nhập đã hết hạn.",
                        onSignIn)
            case .badResponse:
                return ("Lỗi tóm tắt",
                        "AI trả về dữ liệu lạ. Bạn có thể thử lại.",
                        onRetry)
            case .unknown:
                return ("Không tóm tắt được",
                        "Có lỗi không rõ. Bạn có thể thử lại.",
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
                Text(reason == .auth ? "Đăng nhập" : "Thử lại")
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
