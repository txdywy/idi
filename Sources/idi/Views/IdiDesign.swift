import SwiftUI

enum IdiDesign {
    static let canvasTop = Color(red: 0.028, green: 0.032, blue: 0.041)
    static let canvasMid = Color(red: 0.050, green: 0.058, blue: 0.074)
    static let canvasBottom = Color(red: 0.007, green: 0.009, blue: 0.014)
    static let ink = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let secondaryInk = Color(red: 0.68, green: 0.73, blue: 0.78)
    static let tertiaryInk = Color(red: 0.42, green: 0.48, blue: 0.55)
    static let hairline = Color.white.opacity(0.11)
    static let panelBase = Color(red: 0.095, green: 0.115, blue: 0.145)
    static let panelRim = Color(red: 0.52, green: 0.88, blue: 1.0).opacity(0.16)
    static let cyan = Color(red: 0.42, green: 0.88, blue: 1.0)
    static let gold = Color(red: 0.96, green: 0.72, blue: 0.42)

    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ style: Font.TextStyle = .caption, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }

    static func background() -> some View {
        ZStack {
            LinearGradient(colors: [canvasTop, canvasMid, canvasBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [cyan.opacity(0.13), .clear], center: .topLeading, startRadius: 12, endRadius: 560)
            RadialGradient(colors: [gold.opacity(0.075), .clear], center: .bottomTrailing, startRadius: 70, endRadius: 620)
            gridOverlay.opacity(0.22)
        }
    }

    static func panel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.68))
            .background(panelBase.opacity(0.58), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(panelRim, lineWidth: 1))
    }

    static func heroPanel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(colors: [Color.white.opacity(0.075), panelBase.opacity(0.48)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(cyan.opacity(0.20), lineWidth: 1))
            .shadow(color: .black.opacity(0.30), radius: 22, y: 14)
    }

    static func tile(cornerRadius: CGFloat = 14, accent: Color = cyan, active: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(colors: [Color.white.opacity(active ? 0.13 : 0.058), panelBase.opacity(active ? 0.52 : 0.34)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(active ? accent.opacity(0.46) : hairline, lineWidth: 1))
    }

    private static var gridOverlay: some View {
        GeometryReader { proxy in
            Path { path in
                let step: CGFloat = 24
                var x: CGFloat = 0
                while x <= proxy.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += step
                }
            }
            .stroke(Color.white.opacity(0.035), lineWidth: 0.5)
        }
    }
}
