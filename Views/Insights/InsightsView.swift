import SwiftUI

struct InsightsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Insights")
                    .font(.system(size: 24, weight: .bold, design: .default))

                Text("Your learning analytics will appear here.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
        .background(Color(hex: "#FBF9F1"))
    }
}

#Preview {
    InsightsView()
}
