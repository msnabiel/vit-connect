import SwiftUI

/// Keeps the app's intentionally compact custom type sizes responsive to Dynamic Type.
struct VTOPScaledFont: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 17

    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design))
    }
}

extension View {
    func vtopFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(VTOPScaledFont(size: size, weight: weight, design: design))
    }
}
