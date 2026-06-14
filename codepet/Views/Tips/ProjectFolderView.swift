import SwiftUI
import AppKit

// MARK: - Project Color Palette

/// Each project gets a distinct accent color from the brand palette.
/// Colors rotate based on project index.
struct ProjectPalette {
    let fill: Color       // light tinted fill (tab + folder body)
    let mid: Color        // primary accent (buttons, icons, section labels)
    let dark: Color       // darker accent (text on tinted bg)
    let light: Color      // very light tint for folder body background

    /// Brand accent palettes, matching CodepetTheme accents.
    static let palettes: [ProjectPalette] = [
        // Purple — CodepetTheme.accentPurple
        ProjectPalette(
            fill:  Color(hex: "#E8DCFF"),
            mid:   Color(hex: "#7C3AED"),
            dark:  Color(hex: "#5B21B6"),
            light: Color(hex: "#FDFCFF")
        ),
        // Orange — CodepetTheme.accentOrange
        ProjectPalette(
            fill:  Color(hex: "#FFD4B8"),
            mid:   Color(hex: "#E8660A"),
            dark:  Color(hex: "#A04408"),
            light: Color(hex: "#FFFAF6")
        ),
        // Pink — CodepetTheme.accentPink
        ProjectPalette(
            fill:  Color(hex: "#FFD6E5"),
            mid:   Color(hex: "#E0508C"),
            dark:  Color(hex: "#A8305E"),
            light: Color(hex: "#FFFAFC")
        ),
        // Gold — CodepetTheme.accentGold
        ProjectPalette(
            fill:  Color(hex: "#FFEDC0"),
            mid:   Color(hex: "#D49700"),
            dark:  Color(hex: "#8B6914"),
            light: Color(hex: "#FFFDF7")
        ),
        // Blue — CodepetTheme.accentBlue
        ProjectPalette(
            fill:  Color(hex: "#D0E4FE"),
            mid:   Color(hex: "#2563EB"),
            dark:  Color(hex: "#1D4ED8"),
            light: Color(hex: "#FBFCFF")
        ),
        // Coral — CodepetTheme.accentCoral
        ProjectPalette(
            fill:  Color(hex: "#FFD0C8"),
            mid:   Color(hex: "#D94F3A"),
            dark:  Color(hex: "#9C3424"),
            light: Color(hex: "#FFFAF8")
        ),
    ]

    /// Get a palette for a project at the given index (cycles).
    static func forIndex(_ index: Int) -> ProjectPalette {
        palettes[index % palettes.count]
    }
}

// MARK: - Tech-stack tag colors

/// Color for each tech-stack tag pill.
func techTagColor(_ tag: String) -> Color {
    switch tag {
    case "SwiftUI", "UIKit":  return Color(hex: "#7C3AED")
    case "Firebase":          return Color(hex: "#E07020")
    case "React":             return Color(hex: "#2563EB")
    case "Node":              return Color(hex: "#0F9984")
    case "Docker":            return Color(hex: "#2563EB")
    case "Python":            return Color(hex: "#1A6B5C")
    case "Go":                return Color(hex: "#00ADD8")
    case "Rust":              return Color(hex: "#B7410E")
    case "CI/CD":             return Color(hex: "#6B6B6B")
    case "Database":          return Color(hex: "#336791")
    case "API":               return Color(hex: "#D49700")
    case "Tests":             return Color(hex: "#34A853")
    case "Mobile":            return Color(hex: "#E0508C")
    default:                  return Color(hex: "#7C3AED")
    }
}

/// Convert ProjectTag set to sorted human-readable labels.
func projectTagLabels(_ tags: Set<ProjectTag>) -> [String] {
    let mapping: [ProjectTag: String] = [
        .swiftUI: "SwiftUI", .uiKit: "UIKit", .react: "React", .vue: "Vue",
        .angular: "Angular", .python: "Python", .nodeBackend: "Node",
        .goLang: "Go", .rust: "Rust", .firebase: "Firebase", .docker: "Docker",
        .ci: "CI/CD", .database: "Database", .api: "API", .testing: "Tests",
        .mobile: "Mobile",
    ]
    return tags.compactMap { mapping[$0] }.sorted()
}

// MARK: - Pixel Folder Tab Shape

/// A tab shape with stair-step corners on the top, flat bottom.
/// Matches the PixelStaircaseRectangle aesthetic but only applies
/// the staircase to the top-left and top-right corners.
struct PixelFolderTabShape: Shape {
    var blockSize: CGFloat = 4
    var steps: Int = 2

    func path(in rect: CGRect) -> Path {
        let b = blockSize
        let n = steps
        let chamfer = b * CGFloat(n)
        var p = Path()

        // Start: top edge, past top-left chamfer
        p.move(to: CGPoint(x: rect.minX + chamfer, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - chamfer, y: rect.minY))

        // Top-right staircase down-right
        for i in 0..<n {
            let baseX = rect.maxX - b * CGFloat(n - i)
            let baseY = rect.minY + b * CGFloat(i)
            p.addLine(to: CGPoint(x: baseX,     y: baseY + b))
            p.addLine(to: CGPoint(x: baseX + b, y: baseY + b))
        }

        // Right edge straight down to bottom
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // Bottom edge straight across (no staircase)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        // Left edge straight up to staircase
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + chamfer))

        // Top-left staircase up-right
        for i in 0..<n {
            let baseX = rect.minX + b * CGFloat(i)
            let baseY = rect.minY + b * CGFloat(n - i)
            p.addLine(to: CGPoint(x: baseX,     y: baseY - b))
            p.addLine(to: CGPoint(x: baseX + b, y: baseY - b))
        }

        p.closeSubpath()
        return p
    }
}

// MARK: - Pixel Art Icons (Streamline Pixel style, no background)

/// Pixel art folder icon traced from Streamline Pixel `folder.svg`.
/// All coordinates live in a 32×32 viewBox; the Shape scales them to
/// fit whatever frame the caller provides.
struct PixelFolderShape: Shape {
    private static let polygons: [[(CGFloat, CGFloat)]] = [
        // Main body (frame + tab + front panel outline)
        [(30.472,3.045),(28.952,3.045),(28.952,1.525),(27.432,1.525),(27.432,-0.005),
         (6.092,-0.005),(6.092,12.195),(1.522,12.195),(1.522,13.715),(9.142,13.715),
         (9.142,12.195),(7.622,12.195),(7.622,1.525),(24.382,1.525),(24.382,7.615),
         (30.472,7.615),(30.472,22.855),(28.952,22.855),(28.952,25.905),(30.472,25.905),
         (30.472,30.475),(32.002,30.475),(32.002,4.575),(30.472,4.575)],
        // Bottom bar
        [(30.472,30.475),(7.622,30.475),(7.622,31.995),(30.472,31.995)],
        // Diagonal line segments (front panel fold)
        [(28.952,19.805),(27.432,19.805),(27.432,22.855),(28.952,22.855)],
        [(27.432,16.765),(25.902,16.765),(25.902,19.805),(27.432,19.805)],
        [(25.902,15.235),(10.672,15.235),(10.672,16.765),(25.902,16.765)],
        [(10.672,13.715),(9.142,13.715),(9.142,15.235),(10.672,15.235)],
        // Stair-step left edge
        [(7.622,27.425),(6.092,27.425),(6.092,30.475),(7.622,30.475)],
        [(6.092,24.385),(4.572,24.385),(4.572,27.425),(6.092,27.425)],
        [(4.572,21.335),(3.052,21.335),(3.052,24.385),(4.572,24.385)],
        [(3.052,18.285),(1.522,18.285),(1.522,21.335),(3.052,21.335)],
        [(1.522,13.715),(0.002,13.715),(0.002,18.285),(1.522,18.285)],
    ]

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 32.0
        let sy = rect.height / 32.0
        var p = Path()
        for poly in Self.polygons {
            guard let first = poly.first else { continue }
            p.move(to: CGPoint(x: first.0 * sx, y: first.1 * sy))
            for v in poly.dropFirst() {
                p.addLine(to: CGPoint(x: v.0 * sx, y: v.1 * sy))
            }
            p.closeSubpath()
        }
        return p
    }
}

/// Pixel art closed-book-with-bookmark icon traced from Streamline Pixel
/// `content-files-close-book-bookmark.svg`. Same 32×32 viewBox.
struct PixelBookShape: Shape {
    private static let polygons: [[(CGFloat, CGFloat)]] = [
        // Right cover + spine top
        [(3.81,1.52),(28.19,1.52),(28.19,3.05),(26.67,3.05),(26.67,4.57),
         (28.19,4.57),(28.19,7.62),(29.72,7.62),(29.72,30.48),(31.24,30.48),
         (31.24,6.1),(29.72,6.1),(29.72,1.52),(31.24,1.52),(31.24,0),(3.81,0)],
        // Left cover + bottom
        [(6.86,30.48),(6.86,7.62),(16,7.62),(16,6.1),(3.81,6.1),(3.81,7.62),
         (5.34,7.62),(5.34,30.48),(3.81,30.48),(3.81,32),(29.72,32),(29.72,30.48)],
        // Bookmark ribbon
        [(25.15,10.67),(23.62,10.67),(23.62,6.1),(22.1,6.1),(22.1,4.57),
         (23.62,4.57),(23.62,3.05),(16,3.05),(16,4.57),(17.53,4.57),
         (17.53,6.1),(19.05,6.1),(19.05,21.33),(20.57,21.33),(20.57,19.81),
         (22.1,19.81),(22.1,18.29),(23.62,18.29),(23.62,19.81),(25.15,19.81),
         (25.15,21.33),(26.67,21.33),(26.67,6.1),(25.15,6.1)],
        // Bookmark top-right corner
        [(25.15,4.57),(23.62,4.57),(23.62,6.1),(25.15,6.1)],
        // Title bar on cover
        [(14.48,3.05),(5.34,3.05),(5.34,4.57),(14.48,4.57)],
        // Spine bottom-left
        [(3.81,28.95),(2.29,28.95),(2.29,30.48),(3.81,30.48)],
        // Spine top-left
        [(3.81,1.52),(2.29,1.52),(2.29,3.05),(3.81,3.05)],
        // Spine vertical bar
        [(2.29,6.1),(3.81,6.1),(3.81,4.57),(2.29,4.57),(2.29,3.05),
         (0.76,3.05),(0.76,28.95),(2.29,28.95)],
    ]

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 32.0
        let sy = rect.height / 32.0
        var p = Path()
        for poly in Self.polygons {
            guard let first = poly.first else { continue }
            p.move(to: CGPoint(x: first.0 * sx, y: first.1 * sy))
            for v in poly.dropFirst() {
                p.addLine(to: CGPoint(x: v.0 * sx, y: v.1 * sy))
            }
            p.closeSubpath()
        }
        return p
    }
}

/// Convenience view that renders a Streamline Pixel icon in a single color.
/// Usage: `PixelArtIcon(kind: .folder, color: palette.mid, size: 24)`
struct PixelArtIcon: View {
    enum Kind { case folder, book }
    let kind: Kind
    let color: Color
    var size: CGFloat = 24

    var body: some View {
        Group {
            switch kind {
            case .folder:
                PixelFolderShape().fill(color)
            case .book:
                PixelBookShape().fill(color)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Reading Icon Kind

/// Reading type derived from the English prefix of `TipReadingItem.kind`.
enum ReadingIconKind {
    case book, essay, guide, series, reference

    init(fromEnglishKind en: String) {
        let prefix = en.split(separator: " ").first.map { String($0).lowercased() } ?? ""
        switch prefix {
        case "book", "novel":                           self = .book
        case "essay", "paper":                          self = .essay
        case "guide":                                   self = .guide
        case "series", "course", "linked", "connected": self = .series
        case "reference", "repo":                       self = .reference
        default:                                        self = .book
        }
    }
}

// MARK: - Multi-Color Pixel Reading Icon

/// Fun multi-color pixel art icon for each reading type.
/// Each icon is a 14×14 pixel grid drawn via Canvas, scaled to `size`.
struct PixelReadingIcon: View {
    let kind: ReadingIconKind
    var size: CGFloat = 28

    var body: some View {
        Canvas { context, canvasSize in
            let grid = Self.grid(for: kind)
            let rows = grid.count
            let cols = grid.first?.count ?? 0
            guard rows > 0, cols > 0 else { return }
            let px = min(canvasSize.width / CGFloat(cols),
                         canvasSize.height / CGFloat(rows))
            for r in 0..<rows {
                for c in 0..<cols {
                    if let color = grid[r][c] {
                        context.fill(
                            Path(CGRect(x: CGFloat(c) * px, y: CGFloat(r) * px,
                                        width: ceil(px), height: ceil(px))),
                            with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: Grid lookup

    private static func grid(for kind: ReadingIconKind) -> [[Color?]] {
        switch kind {
        case .book:      return bookGrid
        case .essay:     return essayGrid
        case .guide:     return guideGrid
        case .series:    return seriesGrid
        case .reference: return referenceGrid
        }
    }

    // ── Book: red cover · gold ribbon · cream pages ──

    private static let bookGrid: [[Color?]] = {
        let K = Color(hex: "#2D2B26")   // outline
        let R = Color(hex: "#D94444")   // red cover
        let H = Color(hex: "#EF6B6B")   // cover highlight
        let G = Color(hex: "#F0C040")   // gold ribbon
        let P = Color(hex: "#F5F0E0")   // cream pages
        let n: Color? = nil
        return [
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
            [n,K,K,K,K,K,K,K,K,K,K,K,K,n],
            [n,K,R,R,R,R,R,R,R,R,K,P,K,n],
            [n,K,R,H,H,R,R,R,R,R,K,P,K,n],
            [n,K,R,R,R,R,G,G,R,R,K,P,K,n],
            [n,K,R,R,R,R,G,G,R,R,K,P,K,n],
            [n,K,R,R,R,R,R,G,R,R,K,P,K,n],
            [n,K,R,R,R,R,R,G,R,R,K,P,K,n],
            [n,K,R,R,R,R,R,R,R,R,K,P,K,n],
            [n,K,R,R,R,R,R,R,R,R,K,P,K,n],
            [n,K,R,R,R,R,R,R,R,R,K,P,K,n],
            [n,K,R,R,R,R,R,R,R,R,K,P,K,n],
            [n,K,K,K,K,K,K,K,K,K,K,K,K,n],
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
        ]
    }()

    // ── Essay: parchment scroll · text lines · red wax seal ──

    private static let essayGrid: [[Color?]] = {
        let K = Color(hex: "#2D2B26")
        let C = Color(hex: "#F5E8C7")   // parchment
        let D = Color(hex: "#DDD0B0")   // roll shadow
        let L = Color(hex: "#C0B090")   // text lines
        let S = Color(hex: "#D94444")   // seal
        let n: Color? = nil
        return [
            [n,n,K,K,K,K,K,K,K,K,K,K,n,n],
            [n,K,D,D,D,D,D,D,D,D,D,D,K,n],
            [n,K,C,C,C,C,C,C,C,C,C,C,K,n],
            [n,K,C,L,L,L,L,C,C,C,C,C,K,n],
            [n,K,C,C,C,C,C,C,C,C,C,C,K,n],
            [n,K,C,L,L,L,L,L,C,C,C,C,K,n],
            [n,K,C,C,C,C,C,C,C,C,C,C,K,n],
            [n,K,C,L,L,L,L,C,C,C,C,C,K,n],
            [n,K,C,C,C,C,C,C,C,C,C,C,K,n],
            [n,K,D,D,D,D,D,D,D,D,D,D,K,n],
            [n,n,K,K,K,K,K,K,K,K,K,K,n,n],
            [n,n,n,n,n,n,n,n,K,n,n,n,n,n],
            [n,n,n,n,n,n,n,K,S,K,n,n,n,n],
            [n,n,n,n,n,n,n,n,K,n,n,n,n,n],
        ]
    }()

    // ── Guide: glowing lightbulb ──

    private static let guideGrid: [[Color?]] = {
        let K = Color(hex: "#2D2B26")
        let Y = Color(hex: "#FFE066")   // yellow glass
        let W = Color(hex: "#FFF5B0")   // highlight
        let O = Color(hex: "#FF9020")   // filament
        let A = Color(hex: "#B0B0B0")   // base
        let B = Color(hex: "#888888")   // screw
        let n: Color? = nil
        return [
            [n,n,n,n,n,K,K,K,K,n,n,n,n,n],
            [n,n,n,n,K,Y,Y,Y,Y,K,n,n,n,n],
            [n,n,n,K,Y,W,W,Y,Y,Y,K,n,n,n],
            [n,n,K,Y,Y,W,Y,Y,Y,Y,Y,K,n,n],
            [n,n,K,Y,Y,Y,Y,Y,Y,Y,Y,K,n,n],
            [n,n,K,Y,Y,Y,O,O,Y,Y,Y,K,n,n],
            [n,n,n,K,Y,Y,O,Y,Y,Y,K,n,n,n],
            [n,n,n,n,K,Y,Y,Y,Y,K,n,n,n,n],
            [n,n,n,n,K,K,K,K,K,K,n,n,n,n],
            [n,n,n,n,K,A,A,A,A,K,n,n,n,n],
            [n,n,n,n,n,K,A,A,K,n,n,n,n,n],
            [n,n,n,n,n,K,B,B,K,n,n,n,n,n],
            [n,n,n,n,n,n,K,K,n,n,n,n,n,n],
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
        ]
    }()

    // ── Series: three overlapping cards (purple · teal · pink) ──

    private static let seriesGrid: [[Color?]] = {
        let K = Color(hex: "#2D2B26")
        let U = Color(hex: "#C4B5F0")   // purple back card
        let E = Color(hex: "#90E0D0")   // teal middle card
        let I = Color(hex: "#FFB8C8")   // pink front card
        let n: Color? = nil
        return [
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
            [n,n,n,n,n,K,K,K,K,K,K,K,K,n],
            [n,n,n,n,n,K,U,U,U,U,U,U,K,n],
            [n,n,n,K,K,K,K,K,K,K,K,U,K,n],
            [n,n,n,K,E,E,E,E,E,E,K,U,K,n],
            [n,K,K,K,K,K,K,K,K,E,K,U,K,n],
            [n,K,I,I,I,I,I,I,K,E,K,U,K,n],
            [n,K,I,I,I,I,I,I,K,E,K,K,K,n],
            [n,K,I,I,I,I,I,I,K,E,K,n,n,n],
            [n,K,I,I,I,I,I,I,K,K,K,n,n,n],
            [n,K,I,I,I,I,I,I,K,n,n,n,n,n],
            [n,K,K,K,K,K,K,K,K,n,n,n,n,n],
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
        ]
    }()

    // ── Reference: monitor with green code ──

    private static let referenceGrid: [[Color?]] = {
        let K = Color(hex: "#2D2B26")
        let M = Color(hex: "#5B8DD9")   // blue frame
        let F = Color(hex: "#E8E8F0")   // screen
        let J = Color(hex: "#50C878")   // green code
        let A = Color(hex: "#B0B0B0")   // stand
        let n: Color? = nil
        return [
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
            [n,K,K,K,K,K,K,K,K,K,K,K,K,n],
            [n,K,M,M,M,M,M,M,M,M,M,M,K,n],
            [n,K,M,F,F,F,F,F,F,F,F,M,K,n],
            [n,K,M,F,J,F,J,J,F,F,F,M,K,n],
            [n,K,M,F,F,F,F,F,F,F,F,M,K,n],
            [n,K,M,F,J,J,F,J,F,F,F,M,K,n],
            [n,K,M,F,F,F,F,F,F,F,F,M,K,n],
            [n,K,M,M,M,M,M,M,M,M,M,M,K,n],
            [n,K,K,K,K,K,K,K,K,K,K,K,K,n],
            [n,n,n,n,n,K,K,K,K,n,n,n,n,n],
            [n,n,n,n,K,A,A,A,A,K,n,n,n,n],
            [n,n,n,n,K,K,K,K,K,K,n,n,n,n],
            [n,n,n,n,n,n,n,n,n,n,n,n,n,n],
        ]
    }()
}

// MARK: - Single Project Tab Button

struct ProjectTabButton: View {
    let name: String
    let tags: [String]
    let palette: ProjectPalette
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.pixelSystem(size: 13, weight: .bold))
                    .foregroundColor(isActive ? palette.dark : Color(hex: "#2D2B26").opacity(0.5))
                    .lineLimit(1)

                ForEach(tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.pixelSystem(size: 9, weight: .bold))
                        .foregroundColor(isActive ? palette.dark : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isActive ? palette.mid.opacity(0.18) : techTagColor(tag))
                        .overlay(
                            Rectangle()
                                .stroke(
                                    isActive ? palette.mid.opacity(0.3) : Color(hex: "#2D2B26").opacity(0.25),
                                    lineWidth: 1.5
                                )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if !isActive {
                        PixelFolderTabShape(blockSize: 4, steps: 2)
                            .fill(Color(hex: "#2D2B26").opacity(0.06))
                            .offset(x: 2, y: 2)
                    }
                    PixelFolderTabShape(blockSize: 4, steps: 2)
                        .fill(isActive ? palette.fill : Color(hex: "#F0F0F0"))
                    PixelFolderTabShape(blockSize: 4, steps: 2)
                        .stroke(
                            isActive ? Color(hex: "#2D2B26") : Color(hex: "#2D2B26").opacity(0.18),
                            lineWidth: 2
                        )
                }
            )
        }
        .buttonStyle(.plain)
        .zIndex(isActive ? 10 : 1)
        .offset(y: isActive ? 4 : 0) // overlap body
        // Bottom bridge: covers seam between tab and body
        .background(alignment: .bottom) {
            if isActive {
                palette.fill
                    .frame(height: 10)
                    .padding(.horizontal, 2)
                    .offset(y: 8)
            }
        }
    }
}

// MARK: - Folder Content Body

struct ProjectFolderContentView: View {
    let report: ProjectHealthReport
    let readings: [ReadingMatcher.MatchedReading]
    let palette: ProjectPalette
    let uiLanguage: AppLanguage
    let onFeedToClaude: (TipReadingItem, String?) -> Void
    let onOpenURL: (URL) -> Void
    let onLearnMore: (URL) -> Void

    private var missingItems: [ProjectHealthResult] {
        report.results.filter { !$0.passed }
    }

    private var passedItems: [ProjectHealthResult] {
        report.results.filter { $0.passed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Project header ──
            projectHeader

            // ── Needs attention ──
            if !missingItems.isEmpty {
                sectionLabel(
                    icon: "exclamationmark.triangle.fill",
                    text: uiLanguage == .vi ? "Cần chú ý" : "Needs attention",
                    bgColor: Color(hex: "#FFF8E0"),
                    borderColor: Color(hex: "#E09D00"),
                    textColor: Color(hex: "#8B6914")
                )
                ForEach(missingItems) { result in
                    healthRow(result, isMissing: true)
                }
            }

            // ── Passed ──
            if !passedItems.isEmpty {
                sectionLabel(
                    icon: "checkmark.circle.fill",
                    text: uiLanguage == .vi
                        ? "Đã xong (\(passedItems.count))"
                        : "Passed (\(passedItems.count))",
                    bgColor: Color(hex: "#E8F8EC"),
                    borderColor: Color(hex: "#34A853"),
                    textColor: Color(hex: "#1E6B30")
                )
                ForEach(passedItems) { result in
                    healthRow(result, isMissing: false)
                }
            }

            // ── Recommended reading ──
            if !readings.isEmpty {
                sectionLabel(
                    icon: "book.closed.fill",
                    text: uiLanguage == .vi ? "Sách nên đọc" : "Recommended reading",
                    bgColor: palette.fill,
                    borderColor: palette.mid,
                    textColor: palette.dark
                )

                // Horizontal scroll — cards keep fixed size;
                // arrow peeks when more items exist off-screen.
                readingScroll
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [palette.fill, palette.light],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // ── Project header with icon + score ──

    private var projectHeader: some View {
        HStack(spacing: 12) {
            // Project icon — pixel art, no background
            PixelArtIcon(kind: .folder, color: palette.mid, size: 28)

            Text(report.projectName)
                .font(CodepetTheme.pixel(22))
                .foregroundColor(ReflectionTheme.primaryText)

            Spacer()

            // Score pill
            Text("\(report.passedCount)/\(report.totalCount) \(uiLanguage == .vi ? "đạt" : "passed")")
                .font(.pixelSystem(size: 11, weight: .bold))
                .foregroundColor(ReflectionTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    PixelStaircaseRectangle(blockSize: 2, steps: 2)
                        .fill(palette.fill)
                )
                .overlay(
                    PixelStaircaseRectangle(blockSize: 2, steps: 2)
                        .stroke(Color(hex: "#2D2B26"), lineWidth: 2)
                )
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: "#2D2B26"))
                .frame(height: 3)
        }
    }

    // ── Section label (colored left border) ──

    private func sectionLabel(
        icon: String,
        text: String,
        bgColor: Color,
        borderColor: Color,
        textColor: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(text)
                .font(.pixelSystem(size: 12, weight: .bold))
        }
        .foregroundColor(textColor)
        .textCase(.uppercase)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .overlay(alignment: .leading) {
            Rectangle().fill(borderColor).frame(width: 4)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // ── Health check row ──

    private func healthRow(_ result: ProjectHealthResult, isMissing: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Status icon — pixel-art square
            Image(systemName: isMissing ? "xmark" : "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isMissing ? Color(hex: "#8B6914") : Color(hex: "#1E6B30"))
                .frame(width: 20, height: 20)
                .background(isMissing ? Color(hex: "#FCEBA8") : Color(hex: "#B8F0B0"))
                .overlay(
                    Rectangle()
                        .stroke(Color(hex: "#2D2B26"), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(result.rule.title(uiLanguage))
                    .font(.pixelSystem(size: 13, weight: isMissing ? .semibold : .regular))
                    .foregroundColor(isMissing ? ReflectionTheme.primaryText : ReflectionTheme.secondaryText)

                Text(isMissing
                     ? result.rule.missingDescription(uiLanguage)
                     : result.rule.description(uiLanguage))
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(isMissing ? Color(hex: "#A06B00") : ReflectionTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isMissing, let urlString = result.rule.learnMoreURL, let url = URL(string: urlString) {
                Button(action: { onLearnMore(url) }) {
                    Text(uiLanguage == .vi ? "Tìm hiểu" : "Learn more")
                        .font(.pixelSystem(size: 9, weight: .bold))
                }
                .buttonStyle(PixelButtonStyle(
                    fill: palette.mid,
                    foreground: .white,
                    paddingH: 10,
                    paddingV: 4,
                    blockSize: 2,
                    steps: 1,
                    borderWidth: 2,
                    shadowOffset: 2,
                    font: .pixelSystem(size: 9, weight: .bold)
                ))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: "#2D2B26").opacity(0.08))
                .frame(height: 1)
                .padding(.leading, 36)
        }
    }

    // ── Reading scroll (horizontal, with trailing arrow) ──

    private var readingScroll: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(readings.enumerated()), id: \.element.id) { idx, matched in
                        readingCard(matched.item, projectName: matched.projectName, cardIndex: idx)
                            .frame(width: 320)
                    }
                }
                .padding(.bottom, 4) // room for drop shadow
            }

            // Trailing arrow hint when more cards are off-screen
            if readings.count > 2 {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [palette.light.opacity(0), palette.light],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)

                    ZStack {
                        palette.light
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(palette.mid)
                    }
                    .frame(width: 20)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // ── Reading card ──

    /// Codepet brand colors for reading card backgrounds.
    /// Each card cycles through these. `useDarkText` is true when
    /// the background is too light for white text (e.g. yellow, pink).
    private struct CardColor {
        let bg: String
        let useDarkText: Bool
    }
    private static let cardColors: [CardColor] = [
        CardColor(bg: "#9538CF", useDarkText: false),  // Purple
        CardColor(bg: "#1C40CF", useDarkText: false),  // Blue
        CardColor(bg: "#E24B4A", useDarkText: false),  // Red
        CardColor(bg: "#029902", useDarkText: false),  // Green
        CardColor(bg: "#F58345", useDarkText: false),  // Orange
        CardColor(bg: "#FCBE1D", useDarkText: true),   // Yellow
        CardColor(bg: "#FF8CC9", useDarkText: true),   // Pink
    ]

    private func readingCard(_ item: TipReadingItem, projectName: String?, cardIndex: Int) -> some View {
        let card = Self.cardColors[cardIndex % Self.cardColors.count]
        let cardBg = Color(hex: card.bg)
        let textPrimary: Color = card.useDarkText ? Color(hex: "#2D2B26") : .white
        let textSecondary: Color = card.useDarkText ? Color(hex: "#2D2B26").opacity(0.55) : Color.white.opacity(0.55)
        let textBody: Color = card.useDarkText ? Color(hex: "#2D2B26").opacity(0.75) : Color.white.opacity(0.75)

        return HStack(alignment: .center, spacing: 0) {
            // ── Left: icon showcase area ──
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(card.useDarkText ? 0.35 : 0.15))

                // Decorative dots for texture
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(textPrimary.opacity(0.08)).frame(width: 8, height: 8)
                        Spacer()
                        Circle().fill(textPrimary.opacity(0.05)).frame(width: 5, height: 5)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(textPrimary.opacity(0.05)).frame(width: 5, height: 5)
                        Spacer()
                        Circle().fill(textPrimary.opacity(0.08)).frame(width: 8, height: 8)
                    }
                }
                .padding(8)

                PixelReadingIcon(kind: ReadingIconKind(fromEnglishKind: item.kind.en), size: 64)
            }
            .frame(width: 110, height: 110)
            .padding(.leading, 10)
            .padding(.vertical, 10)

            // ── Right: text content + buttons ──
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title(uiLanguage))
                    .font(ReflectionTheme.serif(16, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(item.author) · \(item.kind(uiLanguage))")
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(textSecondary)

                Text(item.why(uiLanguage))
                    .font(.pixelSystem(size: 12))
                    .foregroundColor(textBody)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Spacer(minLength: 6)

                // ── Bottom: buttons right-aligned ──
                HStack(spacing: 6) {
                    Spacer()

                    Button(action: { onFeedToClaude(item, projectName) }) {
                        Text(uiLanguage == .vi ? "Đưa cho Claude" : "Feed to Claude")
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(PixelButtonStyle(
                        fill: .white,
                        foreground: Color(hex: "#2D2B26"),
                        paddingH: 10,
                        paddingV: 5,
                        blockSize: 2,
                        steps: 1,
                        borderWidth: 2,
                        shadowOffset: 2,
                        font: .pixelSystem(size: 10, weight: .semibold)
                    ))

                    if let urlString = item.url, let url = URL(string: urlString) {
                        Button(action: { onOpenURL(url) }) {
                            Text(uiLanguage == .vi ? "Mở" : "Open")
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(PixelButtonStyle(
                            fill: Color.black.opacity(0.25),
                            foreground: .white,
                            paddingH: 10,
                            paddingV: 5,
                            blockSize: 2,
                            steps: 1,
                            borderWidth: 2,
                            shadowOffset: 2,
                            font: .pixelSystem(size: 10, weight: .medium)
                        ))
                    }
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBg)
        .overlay(
            PixelStaircaseRectangle(blockSize: 3, steps: 2)
                .stroke(Color(hex: "#2D2B26"), lineWidth: 3)
        )
        .clipShape(PixelStaircaseRectangle(blockSize: 3, steps: 2))
        .background(
            PixelStaircaseRectangle(blockSize: 3, steps: 2)
                .fill(Color(hex: "#2D2B26"))
                .offset(x: 3, y: 3)
        )
    }
}

// MARK: - Empty folder state

struct ProjectFolderEmptyView: View {
    let uiLanguage: AppLanguage

    var body: some View {
        VStack(spacing: 10) {
            PixelArtIcon(kind: .folder, color: ReflectionTheme.mutedText.opacity(0.4), size: 32)

            Text(uiLanguage == .vi
                 ? "Chưa viết mô tả cho dự án này."
                 : "No brief written yet for this project.")
                .font(.pixelSystem(size: 12))
                .foregroundColor(ReflectionTheme.mutedText)

            Text(uiLanguage == .vi
                 ? "Viết mô tả ngắn để pet đưa ra lời khuyên phù hợp hơn."
                 : "Write a short description so your pet can give tailored advice.")
                .font(.pixelSystem(size: 10))
                .foregroundColor(ReflectionTheme.mutedText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Main Folder Tabs Container

struct ProjectFoldersView: View {
    let projects: [String: Project]
    let readingGroups: [ReadingMatcher.ProjectReadingGroup]
    let healthReports: [ProjectHealthReport]
    let uiLanguage: AppLanguage
    /// The project the user is currently focused on in Reflection. When set (and
    /// known), Project Health follows it: that project becomes the active folder
    /// tab in real time. nil leaves the local selection alone.
    var syncedProjectPath: String? = nil
    let onFeedToClaude: (TipReadingItem, String?) -> Void
    let onOpenURL: (URL) -> Void

    @State private var selectedProjectPath: String?

    /// How many projects show as folder tabs before the rest collapse into
    /// the "+N more" overflow menu. The folder-tab metaphor reads cleanly at a
    /// small count; beyond that the bar gets crowded and starts to scroll.
    private let maxVisibleTabs = 3

    /// Sorted projects (most recent first)
    private var sortedProjects: [(path: String, project: Project)] {
        projects.map { (path: $0.key, project: $0.value) }
            .sorted { $0.project.lastSeenAt > $1.project.lastSeenAt }
    }

    /// The currently selected project path. A local tab tap (selectedProjectPath)
    /// wins; otherwise we mirror the project focused in Reflection
    /// (syncedProjectPath); otherwise we fall back to the most recent.
    private var activeProjectPath: String {
        if let local = selectedProjectPath, projects[local] != nil { return local }
        if let synced = syncedProjectPath, projects[synced] != nil { return synced }
        return sortedProjects.first?.path ?? ""
    }

    /// Projects rendered as folder tabs: the active project first (so the project
    /// focused in Reflection leads the strip), then the most-recent others, up to
    /// `maxVisibleTabs`.
    private var visibleProjects: [(path: String, project: Project)] {
        guard !activeProjectPath.isEmpty,
              let active = sortedProjects.first(where: { $0.path == activeProjectPath }) else {
            return Array(sortedProjects.prefix(maxVisibleTabs))
        }
        let rest = sortedProjects.filter { $0.path != activeProjectPath }
        return Array(([active] + rest).prefix(maxVisibleTabs))
    }

    /// Projects hidden behind the "+N more" menu.
    private var overflowProjects: [(path: String, project: Project)] {
        let visiblePaths = Set(visibleProjects.map { $0.path })
        return sortedProjects.filter { !visiblePaths.contains($0.path) }
    }

    /// Stable palette index keyed to a project's position in the full sorted
    /// list, so its color stays the same whether it's a tab or in the menu.
    private func paletteIndex(for path: String) -> Int {
        sortedProjects.firstIndex(where: { $0.path == path }) ?? 0
    }

    /// Display name, disambiguated with its parent directory when another
    /// project shares the same name (e.g. two `yoga-site` folders).
    private func label(for item: (path: String, project: Project)) -> String {
        let name = item.project.displayName
        let collides = sortedProjects.contains {
            $0.path != item.path && $0.project.displayName == name
        }
        guard collides else { return name }
        let parent = (item.path as NSString).deletingLastPathComponent
        let parentName = (parent as NSString).lastPathComponent
        return parentName.isEmpty ? name : "\(name) · \(parentName)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: uiLanguage == .vi ? "Sức khoẻ dự án" : "Project health")

            if sortedProjects.isEmpty {
                Text(uiLanguage == .vi
                     ? "Chưa có dự án nào được phát hiện."
                     : "No projects detected yet.")
                    .font(ReflectionTheme.serif(13))
                    .foregroundColor(ReflectionTheme.mutedText)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Tabs row ──
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(visibleProjects, id: \.path) { item in
                                let report = healthReports.first { $0.projectPath == item.path }
                                let tags = report.map { projectTagLabels($0.inferredTags) } ?? []
                                let pal = ProjectPalette.forIndex(paletteIndex(for: item.path))
                                let isActive = item.path == activeProjectPath

                                ProjectTabButton(
                                    name: label(for: item),
                                    tags: Array(tags.prefix(2)),
                                    palette: pal,
                                    isActive: isActive,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedProjectPath = item.path
                                        }
                                    }
                                )
                            }

                            // ── Overflow menu: "+N more" ──
                            if !overflowProjects.isEmpty {
                                overflowMenu
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.leading, 8)
                    }

                    // ── Folder body ──
                    let pal = ProjectPalette.forIndex(paletteIndex(for: activeProjectPath))

                    folderBody(for: activeProjectPath, palette: pal)
                        .background(
                            PixelStaircaseRectangle(blockSize: 4, steps: 2)
                                .fill(pal.light)
                        )
                        .overlay(
                            PixelStaircaseRectangle(blockSize: 4, steps: 2)
                                .stroke(Color(hex: "#2D2B26"), lineWidth: 2)
                        )
                        .clipShape(PixelStaircaseRectangle(blockSize: 4, steps: 2))
                }
            }
        }
        .onAppear { followSyncedSelection() }
        .onChange(of: syncedProjectPath) { _ in followSyncedSelection() }
    }

    /// Mirror Reflection's focused project: when `syncedProjectPath` names a
    /// known project, make it the active folder tab. The user can still pick a
    /// different tab afterwards; it holds until Reflection's focus changes again.
    private func followSyncedSelection() {
        guard let path = syncedProjectPath, projects[path] != nil else { return }
        if selectedProjectPath != path {
            selectedProjectPath = path
        }
    }

    /// "+N more" tab that drops down the overflow projects. Selecting one
    /// promotes it to the active folder (and into the visible tab strip).
    private var overflowMenu: some View {
        Menu {
            ForEach(overflowProjects, id: \.path) { item in
                Button(label(for: item)) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedProjectPath = item.path
                    }
                }
            }
        } label: {
            Text(uiLanguage == .vi
                 ? "+\(overflowProjects.count) nữa ▾"
                 : "+\(overflowProjects.count) more ▾")
                .font(.pixelSystem(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    PixelFolderTabShape(blockSize: 4, steps: 2)
                        .fill(Color(hex: "#F0F0F0"))
                )
                .overlay(
                    PixelFolderTabShape(blockSize: 4, steps: 2)
                        .stroke(Color(hex: "#2D2B26").opacity(0.18), lineWidth: 2)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private func folderBody(for projectPath: String, palette: ProjectPalette) -> some View {
        let report = healthReports.first { $0.projectPath == projectPath }
        let readingGroup = readingGroups.first { $0.projectPath == projectPath }
        let readings = readingGroup?.readings ?? []

        if let report = report {
            ProjectFolderContentView(
                report: report,
                readings: readings,
                palette: palette,
                uiLanguage: uiLanguage,
                onFeedToClaude: onFeedToClaude,
                onOpenURL: { NSWorkspace.shared.open($0) },
                onLearnMore: { NSWorkspace.shared.open($0) }
            )
        } else {
            ProjectFolderEmptyView(uiLanguage: uiLanguage)
                .padding(20)
                .background(palette.light)
        }
    }
}
