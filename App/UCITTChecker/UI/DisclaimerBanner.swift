import SwiftUI
import UCITTCore

/// The persistent "estimate, not certification" banner (§1, §5, §9).
struct DisclaimerBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(ResultReport.disclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
