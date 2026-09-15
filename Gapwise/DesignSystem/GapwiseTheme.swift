import SwiftUI

extension Color {
    static let gapwiseAccent = Color("AccentColor")
    static let gapwisePrimarySurface = Color(uiColor: .systemBackground)
    static let gapwiseSecondarySurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let gapwiseSuccess = Color(uiColor: .systemGreen)
}

enum GapwiseSpacing {
    static let compact: CGFloat = 8
    static let standard: CGFloat = 16
    static let spacious: CGFloat = 24
}

enum GapwiseRadius {
    static let card: CGFloat = 8
}

struct GapwiseCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(GapwiseSpacing.standard)
            .background(
                Color.gapwiseSecondarySurface,
                in: RoundedRectangle(cornerRadius: GapwiseRadius.card)
            )
    }
}

extension View {
    func gapwiseCard() -> some View {
        modifier(GapwiseCardModifier())
    }
}
