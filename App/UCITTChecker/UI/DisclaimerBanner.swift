import SwiftUI
import UCITTCore

/// The persistent "estimate, not certification" banner (§1, §5, §9).
struct DisclaimerBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.check)
            Text(ResultReport.disclaimer)
                .font(Theme.body(12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.check.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.check.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
