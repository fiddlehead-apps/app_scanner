import SwiftUI

/// Sola palette, light and dark. Same neutrals as the other Sola apps, teal as accent.
nonisolated extension Color {
    static let bg = dynamic(0xEEF0F3, 0x121418)
    static let surface = dynamic(0xFFFFFF, 0x1C1F25)
    static let ink = dynamic(0x16181D, 0xF1F2F4)
    static let muted = dynamic(0x5D6470, 0x9AA1AD)
    static let line = dynamic(0xD5D9E0, 0x2C3038)
    static let brand = dynamic(0x0B8A7E, 0x4FD6C2)
    static let brandInk = dynamic(0xFFFFFF, 0x062C27)
    static let brandSoft = dynamic(0xD9F2EE, 0x15322E)
    static let good = dynamic(0x1E9E5A, 0x4CD787)
    static let goodSoft = dynamic(0xDDF5E7, 0x173326)
    static let danger = dynamic(0xC4321F, 0xE5533E)
    static let dangerSoft = dynamic(0xFBE2DE, 0x3A1E1A)
    static let sun = Color(hex: 0xFFC857)

    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { t in UIColor(Color(hex: t.userInterfaceStyle == .dark ? dark : light)) })
    }
}

/// The big filled / outlined buttons, as in the other Sola apps.
struct BigButtonStyle: ButtonStyle {
    var primary: Bool
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 22)
            .foregroundStyle(primary ? Color.brandInk : Color.ink)
            .background(primary ? Color.brand : Color.surface, in: .rect(cornerRadius: 16))
            .overlay {
                if !primary { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line, lineWidth: 1.5) }
            }
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Press feedback for cards and tiles that bring their own background.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Round outlined icon button for the top bar.
struct CircleIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .background(Color.surface, in: .circle)
                .overlay(Circle().strokeBorder(Color.line, lineWidth: 1.5))
        }
        .accessibilityLabel(label)
    }
}

extension View {
    /// White card with a thin border.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.line, lineWidth: 1.5))
    }

    /// Small grey heading above a block.
    func sectionTitle() -> some View {
        self.font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Lays out its children left to right and wraps into new lines, like words in a text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.items.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
