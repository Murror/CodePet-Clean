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
                            lineWidth: 3
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
    /// The project these checks belong to — source of brief/domains for plan generation.
    let project: Project
    let readings: [ReadingMatcher.MatchedReading]
    let palette: ProjectPalette
    let uiLanguage: AppLanguage
    let onFeedToClaude: (TipReadingItem, String?) -> Void
    let onOpenURL: (URL) -> Void
    let onLearnMore: (URL) -> Void
    /// nil stage = revert to engine-inferred. Set by the header stage picker.
    let onSetStage: (ProjectStage?) -> Void
    /// Toggle a self-attested check ("Mark done" / undo).
    let onToggleAttestation: (String) -> Void

    /// Generates per-section action plans on demand.
    @ObservedObject var planEnricher: PlanEnricher
    /// Holds the cached plans (plansByKey) the panel reads.
    @EnvironmentObject var tipsState: TipsState

    /// "Coming up later" is collapsed by default — it's forward-looking,
    /// non-actionable context, and at early stages it can be 9+ rows.
    @State private var upcomingExpanded = false

    /// The check whose plan is shown in the modal layer (nil = no sheet).
    @State private var planSheet: PlanSheetTarget?

    /// Pillars whose checks are expanded. Empty = all collapsed (compact
    /// dropdown view; the header score still shows status at a glance).
    @State private var expandedPillars: Set<HealthPillar> = []

    /// Rule ids whose plan the user has revealed past the free preview.
    /// (Progressive disclosure now; becomes the purchase gate when gating is on.)
    @State private var unlockedPlans: Set<String> = []

    /// Identifiable wrapper so the plan opens via `.sheet(item:)`.
    private struct PlanSheetTarget: Identifiable {
        let result: ProjectHealthResult
        var id: String { result.rule.id }
    }

    /// Pillars that actually have relevant checks for this project, in display order.
    private var activePillars: [HealthPillar] {
        HealthPillar.allCases
            .sorted { $0.order < $1.order }
            .filter { !report.results(for: $0).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Project header ──
            projectHeader

            // ── One section per pillar (Engineering · Business · Growth) ──
            // Within each, missing items sort first (see engine sort), so the
            // pet's advice leads with what needs attention now.
            ForEach(activePillars, id: \.self) { pillar in
                pillarSection(pillar)
            }

            // ── Coming up later (stage-gated checks) — collapsed by default ──
            if !report.upcoming.isEmpty {
                upcomingSection
            }

            // ── Recommended reading ──
            sectionLabel(
                icon: "book.closed.fill",
                text: uiLanguage == .vi ? "Sách nên đọc" : "Recommended reading",
                iconColor: .white
            )

            if !readings.isEmpty {
                // Horizontal scroll — cards keep fixed size;
                // arrow peeks when more items exist off-screen.
                readingScroll
            } else {
                // Not enough signal to recommend project-specific books yet.
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                    Text(uiLanguage == .vi
                         ? "Chưa đủ thông tin về dự án này để gợi ý sách phù hợp. Viết mô tả dự án (project brief) hoặc tiếp tục code ở đây — mình sẽ nhận ra công nghệ bạn dùng và gợi ý sách đúng với nó."
                         : "Not enough info about this project yet to suggest books that fit it. Add a project brief, or keep coding here — I'll learn its tech and recommend reading that matches.")
                        .font(.pixelSystem(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .foregroundColor(Color.white.opacity(0.9))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        // Solid vivid brand color — same treatment as the agentic-coding skill
        // cards. Inner content uses white text for contrast on this strong bg.
        .background(palette.mid)
        // Plan opens in its own modal layer (keeps the folder compact).
        .sheet(item: $planSheet) { target in
            planSheetView(target.result)
        }
    }

    // ── Project header with icon + score ──

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Project icon — pixel art, no background
                PixelArtIcon(kind: .folder, color: .white, size: 28)

                Text(report.projectName)
                    .font(CodepetTheme.body(22, weight: .bold))
                    .foregroundColor(.white)

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

            // Stage picker — drives which checks are relevant now vs. later.
            stagePicker
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 3)
        }
    }

    // ── Stage picker ──

    /// A small menu that sets the project's lifecycle stage. The current stage
    /// drives `relevantFrom` gating in the engine. "Auto" reverts to inference.
    private var stagePicker: some View {
        HStack(spacing: 7) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))

            Text(uiLanguage == .vi ? "Giai đoạn:" : "Stage:")
                .font(.pixelSystem(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            Menu {
                ForEach(ProjectStage.allCases) { stage in
                    Button(stage.label(uiLanguage)) { onSetStage(stage) }
                }
                Divider()
                Button(uiLanguage == .vi ? "Tự động" : "Auto-detect") { onSetStage(nil) }
            } label: {
                HStack(spacing: 4) {
                    Text(report.stage.label(uiLanguage))
                        .font(.pixelSystem(size: 11, weight: .bold))
                        .foregroundColor(palette.dark)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(palette.dark)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    PixelStaircaseRectangle(blockSize: 2, steps: 1)
                        .fill(palette.fill)
                )
                .overlay(
                    PixelStaircaseRectangle(blockSize: 2, steps: 1)
                        .stroke(Color(hex: "#2D2B26"), lineWidth: 1.5)
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer()
        }
    }

    // ── Pillar section (Engineering · Business · Growth) — collapsible ──

    @ViewBuilder
    private func pillarSection(_ pillar: HealthPillar) -> some View {
        let items = report.results(for: pillar)
        let passed = items.filter(\.passed).count
        let open = expandedPillars.contains(pillar)

        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if open { expandedPillars.remove(pillar) } else { expandedPillars.insert(pillar) }
                }
            }) {
                HStack(spacing: 7) {
                    Image(systemName: pillarIcon(pillar))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(pillarColor(pillar))
                    Text("\(pillar.label(uiLanguage).uppercased()) \(passed)/\(items.count)")
                        .font(.pixelSystem(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(0.5)
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.top, 14)
                .padding(.bottom, open ? 8 : 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                ForEach(items) { result in
                    healthRow(result)
                }
            }
        }
    }

    private func pillarIcon(_ pillar: HealthPillar) -> String {
        switch pillar {
        case .engineering: return "hammer.fill"
        case .business:    return "dollarsign.circle.fill"
        case .growth:      return "chart.line.uptrend.xyaxis"
        }
    }

    private func pillarColor(_ pillar: HealthPillar) -> Color {
        switch pillar {
        case .engineering: return Color(hex: "#9BD0FF")
        case .business:    return Color(hex: "#7CE0A3")
        case .growth:      return Color(hex: "#FFCC33")
        }
    }

    // ── Section label (colored left border) ──

    /// Minimal section label — no band, no divider line. White uppercase text
    /// + a colored status icon (the icon carries the color meaning). Sections
    /// are separated by whitespace alone for a clean, simple look.
    private func sectionLabel(
        icon: String,
        text: String,
        iconColor: Color
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(iconColor)
            Text(text)
                .font(.pixelSystem(size: 16, weight: .bold))
                .foregroundColor(.white)
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // ── Coming up later (collapsible) ──

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { upcomingExpanded.toggle() }
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Text((uiLanguage == .vi ? "Sắp tới" : "Coming up later")
                         + " (\(report.upcoming.count))")
                        .font(.pixelSystem(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Image(systemName: upcomingExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.top, 14)
                .padding(.bottom, upcomingExpanded ? 8 : 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if upcomingExpanded {
                ForEach(report.upcoming) { result in
                    upcomingRow(result)
                }
            }
        }
    }

    // ── Health check row ──

    private func healthRow(_ result: ProjectHealthResult) -> some View {
        let isMissing = !result.passed
        // Auto-detected passes can't be toggled (they reflect the files);
        // everything else can be confirmed/undone by the user.
        let canToggle = result.state != .passed
        let planKey = SectionPlan.key(
            projectPath: project.id, ruleId: result.rule.id, stage: report.stage.rawValue
        )

        return HStack(alignment: .center, spacing: 12) {
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
                    .foregroundColor(isMissing ? .white : Color.white.opacity(0.85))

                Text(isMissing
                     ? result.rule.missingDescription(uiLanguage)
                     : result.rule.description(uiLanguage))
                    .font(.pixelSystem(size: 11))
                    .foregroundColor(Color.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isMissing, let urlString = result.rule.learnMoreURL, let url = URL(string: urlString) {
                Button(action: { onLearnMore(url) }) {
                    Text(uiLanguage == .vi ? "Tìm hiểu" : "Learn more")
                        .font(.pixelSystem(size: 9, weight: .bold))
                }
                .buttonStyle(PixelButtonStyle(
                    fill: .white, foreground: palette.dark,
                    paddingH: 10, paddingV: 4, blockSize: 2, steps: 1,
                    borderWidth: 2, shadowOffset: 2,
                    font: .pixelSystem(size: 9, weight: .bold)
                ))
            }

            // Get plan / View plan — opens the action plan in a modal layer.
            if isMissing {
                Button(action: { openPlan(result) }) {
                    Text(planButtonLabel(key: planKey))
                        .font(.pixelSystem(size: 9, weight: .bold))
                }
                .buttonStyle(PixelButtonStyle(
                    fill: .white, foreground: palette.dark,
                    paddingH: 10, paddingV: 4, blockSize: 2, steps: 1,
                    borderWidth: 2, shadowOffset: 2,
                    font: .pixelSystem(size: 9, weight: .bold)
                ))
            }

            // Mark done / undo — for self-attested checks and missing auto checks.
            if canToggle {
                Button(action: { onToggleAttestation(result.rule.id) }) {
                    Text(isMissing
                         ? (uiLanguage == .vi ? "Đánh dấu xong" : "Mark done")
                         : (uiLanguage == .vi ? "Hoàn tác" : "Undo"))
                        .font(.pixelSystem(size: 9, weight: .bold))
                }
                .buttonStyle(PixelButtonStyle(
                    fill: isMissing ? palette.fill : Color.black.opacity(0.2),
                    foreground: isMissing ? palette.dark : .white,
                    paddingH: 10, paddingV: 4, blockSize: 2, steps: 1,
                    borderWidth: 2, shadowOffset: 2,
                    font: .pixelSystem(size: 9, weight: .bold)
                ))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    // ── Plan: button label, open, modal layer ──

    private func planButtonLabel(key: String) -> String {
        if tipsState.plansByKey[key] != nil { return uiLanguage == .vi ? "Xem kế hoạch" : "View plan" }
        return uiLanguage == .vi ? "Lập kế hoạch" : "Get plan"
    }

    /// Open the plan in its modal layer and kick off generation (cache-or-fetch).
    private func openPlan(_ result: ProjectHealthResult) {
        planSheet = PlanSheetTarget(result: result)
        Task {
            await planEnricher.generatePlan(
                project: project, report: report, result: result,
                language: uiLanguage, tipsState: tipsState
            )
        }
    }

    /// The plan modal: header bar + scrollable body (loading / error / plan).
    @ViewBuilder
    private func planSheetView(_ result: ProjectHealthResult) -> some View {
        let key = SectionPlan.key(
            projectPath: project.id, ruleId: result.rule.id, stage: report.stage.rawValue
        )
        VStack(spacing: 0) {
            // Header bar
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(uiLanguage == .vi ? "Kế hoạch hành động" : "Action plan")
                        .font(.pixelSystem(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Text(result.rule.title(uiLanguage))
                        .font(.pixelSystem(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                // Regenerate — fetches a fresh plan (e.g. after a prompt change).
                Button(action: {
                    unlockedPlans.remove(result.rule.id)
                    Task {
                        await planEnricher.generatePlan(
                            project: project, report: report, result: result,
                            language: uiLanguage, tipsState: tipsState, force: true
                        )
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(PixelButtonStyle(
                    fill: .white, foreground: palette.dark,
                    paddingH: 9, paddingV: 7, blockSize: 2, steps: 1,
                    borderWidth: 2, shadowOffset: 2,
                    font: .pixelSystem(size: 11, weight: .bold)
                ))
                Button(action: { planSheet = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(PixelButtonStyle(
                    fill: .white, foreground: palette.dark,
                    paddingH: 9, paddingV: 7, blockSize: 2, steps: 1,
                    borderWidth: 2, shadowOffset: 2,
                    font: .pixelSystem(size: 11, weight: .bold)
                ))
            }
            .padding(16)
            .background(palette.dark)

            // Body
            ScrollView {
                Group {
                    if planEnricher.isLoading(key) {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(palette.dark)
                            Text(uiLanguage == .vi ? "Đang lập kế hoạch…" : "Generating plan…")
                                .font(.pixelSystem(size: 12))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    } else if let plan = tipsState.plansByKey[key] {
                        planContent(plan, result: result)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color(hex: "#E8660A"))
                                Text(uiLanguage == .vi
                                     ? "Không lập được kế hoạch."
                                     : "Couldn't generate a plan.")
                                    .font(.pixelSystem(size: 12))
                                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.9))
                            }
                            Button(action: {
                                Task {
                                    await planEnricher.generatePlan(
                                        project: project, report: report, result: result,
                                        language: uiLanguage, tipsState: tipsState, force: true
                                    )
                                }
                            }) {
                                Text(uiLanguage == .vi ? "Thử lại" : "Retry")
                                    .font(.pixelSystem(size: 11, weight: .bold))
                            }
                            .buttonStyle(PixelButtonStyle(
                                fill: palette.mid, foreground: .white,
                                paddingH: 14, paddingV: 7, blockSize: 2, steps: 1,
                                borderWidth: 2, shadowOffset: 2,
                                font: .pixelSystem(size: 11, weight: .bold)
                            ))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 560, height: 540)
        .background(palette.light)
    }

    @ViewBuilder
    private func planContent(_ plan: SectionPlan, result: ProjectHealthResult) -> some View {
        let unlocked = unlockedPlans.contains(result.rule.id)
        // Free preview shows ~half the steps; the rest are blurred behind the
        // unlock CTA. Once unlocked, the whole plan (and pitfalls) is shown.
        let previewCount = max(1, plan.steps.count / 2)
        let visibleCount = unlocked ? plan.steps.count : min(previewCount, plan.steps.count)
        let hiddenCount = plan.steps.count - visibleCount

        VStack(alignment: .leading, spacing: 14) {
            // Summary
            Text(plan.summary)
                .font(.pixelSystem(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#2D2B26"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Visible steps
            ForEach(0..<visibleCount, id: \.self) { idx in
                planStepRow(index: idx + 1, step: plan.steps[idx])
            }

            // Locked preview: blurred peek at the next step + unlock CTA
            if !unlocked && hiddenCount > 0 {
                lockedTeaser(plan: plan, result: result,
                             hiddenCount: hiddenCount, nextIndex: visibleCount + 1)
            }

            // Pitfalls (full plan only)
            if unlocked && !plan.pitfalls.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(uiLanguage == .vi ? "TRÁNH" : "AVOID")
                        .font(.pixelSystem(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.55))
                        .tracking(0.5)
                    ForEach(Array(plan.pitfalls.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundColor(Color(hex: "#2D2B26").opacity(0.55))
                            Text(p)
                                .font(.pixelSystem(size: 13))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.8))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
    }

    /// Blurred peek at the remaining steps + the unlock CTA. Keeps the panel
    /// compact by default and doubles as the freemium teaser.
    private func lockedTeaser(
        plan: SectionPlan, result: ProjectHealthResult,
        hiddenCount: Int, nextIndex: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // A short, blurred glimpse of the next step so it reads as "there's more".
            if nextIndex - 1 < plan.steps.count {
                planStepRow(index: nextIndex, step: plan.steps[nextIndex - 1])
                    .frame(maxHeight: 64, alignment: .top)
                    .clipped()
                    .blur(radius: 6)
                    .opacity(0.65)
                    .allowsHitTesting(false)
                    .overlay(
                        LinearGradient(
                            colors: [palette.light.opacity(0), palette.light],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            Button(action: { revealPlan(result, plan) }) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                    Text((uiLanguage == .vi
                          ? "Mở khoá để xem toàn bộ kế hoạch"
                          : "Unlock to view full plan details")
                         + " (\(hiddenCount))")
                }
            }
            .buttonStyle(PixelButtonStyle(
                fill: palette.mid, foreground: .white,
                paddingH: 14, paddingV: 7, blockSize: 2, steps: 1,
                borderWidth: 2, shadowOffset: 2,
                font: .pixelSystem(size: 11, weight: .bold)
            ))
        }
    }

    /// Reveal the rest of the plan. While gating is OFF the full content is
    /// already present, so this is a free progressive-disclosure reveal. When
    /// gating is ON the withheld steps have no content and this is where a
    /// purchase flow would hook in (step 4 client work, not yet built).
    private func revealPlan(_ result: ProjectHealthResult, _ plan: SectionPlan) {
        withAnimation(.easeInOut(duration: 0.18)) {
            unlockedPlans.insert(result.rule.id)
        }
        // TODO(monetization): if plan.lockedStepCount > 0 (server-gated), route
        // to the purchase flow instead of revealing.
    }

    private func planStepRow(index: Int, step: SectionPlan.Step) -> some View {
        let locked = step.detail == nil
        return HStack(alignment: .top, spacing: 10) {
            // Step number / lock badge
            ZStack {
                Rectangle()
                    .fill(locked ? palette.fill.opacity(0.6) : palette.mid)
                    .frame(width: 26, height: 26)
                    .overlay(Rectangle().stroke(Color(hex: "#2D2B26").opacity(locked ? 0.15 : 0.5), lineWidth: 2))
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                } else {
                    Text("\(index)")
                        .font(.pixelSystem(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.pixelSystem(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(locked ? 0.5 : 1.0))
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = step.detail {
                    Text(detail)
                        .font(.pixelSystem(size: 13))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.82))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if !step.doneWhen.isEmpty {
                        Text((uiLanguage == .vi ? "Xong khi: " : "Done when: ") + step.doneWhen)
                            .font(.pixelSystem(size: 12))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // ── Upcoming (stage-gated) row ──

    /// A check that isn't relevant yet at the project's current stage. Shown
    /// muted with the stage it unlocks at, so the roadmap is visible without
    /// nagging the user about work that isn't due.
    private func upcomingRow(_ result: ProjectHealthResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.12))
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )

            Text(result.rule.title(uiLanguage))
                .font(.pixelSystem(size: 12))
                .foregroundColor(Color.white.opacity(0.65))

            Spacer()

            // Stage chip — when this check unlocks.
            Text(result.rule.relevantFrom.label(uiLanguage))
                .font(.pixelSystem(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.15))
                .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
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
                        colors: [palette.mid.opacity(0), palette.mid],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)

                    ZStack {
                        palette.mid
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
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
        // White outline so the card never blends into the vivid body
        // background — even when the card color is close to the project color
        // (e.g. a blue card on a blue project).
        .overlay(
            PixelStaircaseRectangle(blockSize: 3, steps: 2)
                .stroke(Color.white, lineWidth: 3)
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
    let onFeedToClaude: (TipReadingItem, String?) -> Void
    let onOpenURL: (URL) -> Void
    /// (projectPath, stage) — nil stage reverts to engine inference.
    let onSetStage: (String, ProjectStage?) -> Void
    /// (projectPath, ruleId) — toggle a self-attested check.
    let onToggleAttestation: (String, String) -> Void
    /// Generates per-section action plans (shared across folders).
    @ObservedObject var planEnricher: PlanEnricher

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

    /// The currently selected project path (defaults to first)
    private var activeProjectPath: String {
        selectedProjectPath ?? sortedProjects.first?.path ?? ""
    }

    /// Projects rendered as folder tabs: the most-recent `maxVisibleTabs`,
    /// but always including the active one (so a project picked from the
    /// overflow menu surfaces as a tab instead of vanishing).
    private var visibleProjects: [(path: String, project: Project)] {
        let top = Array(sortedProjects.prefix(maxVisibleTabs))
        if activeProjectPath.isEmpty || top.contains(where: { $0.path == activeProjectPath }) {
            return top
        }
        guard let active = sortedProjects.first(where: { $0.path == activeProjectPath }) else {
            return top
        }
        return [active] + top.prefix(maxVisibleTabs - 1)
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
                            // Sits flush against the last project tab (zero
                            // spacing), matching the gap between the tabs.
                            if !overflowProjects.isEmpty {
                                overflowMenu
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
                                .stroke(Color(hex: "#2D2B26"), lineWidth: 3)
                        )
                        .clipShape(PixelStaircaseRectangle(blockSize: 4, steps: 2))
                        // Drop-shadow edge so the whole box reads as solidly
                        // thick, matching the Focus Today / reading cards.
                        .background(
                            PixelStaircaseRectangle(blockSize: 4, steps: 2)
                                .fill(Color(hex: "#2D2B26"))
                                .offset(x: 3, y: 3)
                        )
                }
            }
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
            // Compact dropdown-arrow tab framed like a project folder tab so it
            // reads as a defined sibling rather than a faint ghost. Uses the
            // same solid border + drop shadow as the project tabs, with the
            // chevron centered. The hidden-project count lives in the tooltip
            // to keep the face minimal.
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        // Drop shadow — same depth as the inactive project tabs.
                        PixelFolderTabShape(blockSize: 4, steps: 2)
                            .fill(Color(hex: "#2D2B26").opacity(0.06))
                            .offset(x: 2, y: 2)
                        // Tab fill — same as the inactive 'sprout'/'codepet-pixel' tabs.
                        PixelFolderTabShape(blockSize: 4, steps: 2)
                            .fill(Color(hex: "#F0F0F0"))
                        // Border — matches the inactive project tabs exactly.
                        PixelFolderTabShape(blockSize: 4, steps: 2)
                            .stroke(Color(hex: "#2D2B26").opacity(0.18), lineWidth: 1.5)
                    }
                )
        }
        // .button style + plain button style renders the label at full color
        // fidelity. The default/borderlessButton menu style dims and restyles
        // custom labels, which washed out the folder-tab border.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(uiLanguage == .vi
              ? "\(overflowProjects.count) dự án khác"
              : "\(overflowProjects.count) more projects")
    }

    @ViewBuilder
    private func folderBody(for projectPath: String, palette: ProjectPalette) -> some View {
        let report = healthReports.first { $0.projectPath == projectPath }
        let readingGroup = readingGroups.first { $0.projectPath == projectPath }
        let readings = readingGroup?.readings ?? []

        if let report = report, let project = projects[projectPath] {
            ProjectFolderContentView(
                report: report,
                project: project,
                readings: readings,
                palette: palette,
                uiLanguage: uiLanguage,
                onFeedToClaude: onFeedToClaude,
                onOpenURL: { NSWorkspace.shared.open($0) },
                onLearnMore: { NSWorkspace.shared.open($0) },
                onSetStage: { stage in onSetStage(projectPath, stage) },
                onToggleAttestation: { ruleId in onToggleAttestation(projectPath, ruleId) },
                planEnricher: planEnricher
            )
        } else {
            ProjectFolderEmptyView(uiLanguage: uiLanguage)
                .padding(20)
                .background(palette.light)
        }
    }
}
