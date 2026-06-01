import Foundation

// MARK: - Project Signal Inference

/// Infers `ProjectTag`s from a project's file-system path by looking at known
/// file extensions, config files, and directory names in the project root.
///
/// This runs purely on the path string — no file-system I/O — so it's safe
/// to call from the main thread.
enum ProjectSignals {

    /// Mapping: file/directory pattern → inferred tags.
    /// Patterns are checked against the last path component OR well-known
    /// nested paths (e.g. ".github/workflows").
    private static let rules: [(pattern: String, tags: [ProjectTag])] = [
        // Swift / Apple
        (".xcodeproj",               [.swiftUI, .mobile]),
        (".xcworkspace",             [.swiftUI, .mobile]),
        ("Package.swift",            [.swiftUI]),
        ("GoogleService-Info.plist", [.firebase]),
        ("firebase.json",           [.firebase]),
        (".firebaserc",             [.firebase]),

        // Web frontend
        ("package.json",            [.nodeBackend]),   // refined below by deps
        ("next.config",             [.react]),
        ("nuxt.config",             [.vue]),
        ("angular.json",            [.angular]),
        ("vite.config",             [.react]),         // most Vite users are React
        ("tsconfig.json",           [.react]),         // loose signal, overridden by framework

        // Python
        ("requirements.txt",        [.python]),
        ("pyproject.toml",          [.python]),
        ("setup.py",                [.python]),
        ("Pipfile",                 [.python]),

        // Go
        ("go.mod",                  [.goLang]),

        // Rust
        ("Cargo.toml",             [.rust]),

        // Infra
        ("Dockerfile",             [.docker]),
        ("docker-compose",         [.docker]),
        (".github/workflows",      [.ci]),
        (".gitlab-ci.yml",         [.ci]),
        ("Jenkinsfile",            [.ci]),

        // Database
        ("prisma",                 [.database]),
        (".sql",                   [.database]),
        ("knexfile",               [.database]),
        ("sequelize",              [.database]),

        // API
        ("openapi",                [.api]),
        ("swagger",                [.api]),
        ("schema.graphql",         [.api]),

        // Testing
        ("XCTest",                 [.testing]),
        ("jest.config",            [.testing]),
        ("pytest",                 [.testing]),
        (".test.",                 [.testing]),
        (".spec.",                 [.testing]),
    ]

    /// Infer tags from a project root path.
    /// The path string is searched for known markers — this does NOT read the
    /// file system, so it works in sandboxed environments.
    static func inferTags(from projectPath: String) -> Set<ProjectTag> {
        var tags = Set<ProjectTag>()
        let lowered = projectPath.lowercased()

        for rule in rules {
            if lowered.contains(rule.pattern.lowercased()) {
                tags.formUnion(rule.tags)
            }
        }

        return tags
    }

    /// Infer tags from a project path + its brief text.
    /// The brief often contains keywords like "SwiftUI", "React", "Firebase"
    /// that give strong signals about the tech stack.
    static func inferTags(from projectPath: String, brief: String) -> Set<ProjectTag> {
        var tags = inferTags(from: projectPath)

        let briefLower = brief.lowercased()
        let briefRules: [(keyword: String, tags: [ProjectTag])] = [
            ("swiftui",      [.swiftUI]),
            ("uikit",        [.uiKit]),
            ("react",        [.react]),
            ("vue",          [.vue]),
            ("angular",      [.angular]),
            ("python",       [.python]),
            ("django",       [.python, .api]),
            ("flask",        [.python, .api]),
            ("fastapi",      [.python, .api]),
            ("node",         [.nodeBackend]),
            ("express",      [.nodeBackend, .api]),
            ("firebase",     [.firebase]),
            ("firestore",    [.firebase, .database]),
            ("docker",       [.docker]),
            ("kubernetes",   [.docker]),
            ("ci/cd",        [.ci]),
            ("github actions", [.ci]),
            ("postgres",     [.database]),
            ("mongodb",      [.database]),
            ("core data",    [.database, .swiftUI]),
            ("graphql",      [.api]),
            ("rest api",     [.api]),
            ("core ml",      [.swiftUI, .mobile]),
            ("ios",          [.mobile, .swiftUI]),
            ("android",      [.mobile]),
            ("macos",        [.swiftUI]),
            ("golang",       [.goLang]),
            ("rust",         [.rust]),
        ]

        for rule in briefRules {
            if briefLower.contains(rule.keyword) {
                tags.formUnion(rule.tags)
            }
        }

        return tags
    }
}

// MARK: - Reading Matcher

/// Matches readings from the expanded pool to user projects.
///
/// Algorithm:
/// 1. Filter pool by the active pet's domain
/// 2. For each project, score each reading by tag overlap
/// 3. Pick top N per project (default 2-3)
/// 4. If no projects exist, fall back to the pet's first 2 entries (universal picks)
struct ReadingMatcher {

    /// A reading matched to a specific project.
    struct MatchedReading: Identifiable {
        let item: TipReadingItem
        let projectName: String?      // nil = universal / no-project fallback
        let projectPath: String?      // nil = universal
        let score: Int                // tag overlap count

        var id: String {
            "\(projectPath ?? "__universal__")_\(item.title(.en))"
        }
    }

    /// A group of readings matched to a project.
    struct ProjectReadingGroup: Identifiable {
        let projectName: String
        let projectPath: String?      // nil = universal fallback
        let readings: [MatchedReading]
        var id: String { projectPath ?? "__universal__" }
    }

    /// Match readings for the active pet against the user's projects.
    ///
    /// - Parameters:
    ///   - petId: The active pet character ID (e.g. "crash", "nova")
    ///   - projects: All known projects from ProjectStore
    ///   - maxPerProject: Maximum readings to show per project (default 3)
    /// - Returns: Reading groups sorted by project recency, or a single
    ///   universal group if no projects exist.
    static func match(
        petId: String,
        projects: [String: Project],
        maxPerProject: Int = 3
    ) -> [ProjectReadingGroup] {
        let pool = TipsContent.tipReadingPool[petId] ?? []
        guard !pool.isEmpty else { return [] }

        // No projects → fall back to first 2 readings (the "universal" picks)
        let sortedProjects = projects.values.sorted { $0.lastSeenAt > $1.lastSeenAt }
        if sortedProjects.isEmpty {
            let fallback = Array(pool.prefix(2)).map { item in
                MatchedReading(item: item, projectName: nil, projectPath: nil, score: 0)
            }
            return [ProjectReadingGroup(
                projectName: "General",
                projectPath: nil,
                readings: fallback
            )]
        }

        var groups: [ProjectReadingGroup] = []
        var usedTitles = Set<String>()  // avoid recommending same book for multiple projects

        for project in sortedProjects {
            let projectTags = ProjectSignals.inferTags(from: project.id, brief: project.brief)

            // Score each reading by tag overlap
            var scored: [(item: TipReadingItem, score: Int)] = pool.compactMap { item in
                // Skip already-used titles
                let titleKey = item.title(.en)
                guard !usedTitles.contains(titleKey) else { return nil }

                if item.tags.isEmpty {
                    // Universal reading (no tags) — score 0, still eligible as fallback
                    return (item, 0)
                }
                let overlap = Set(item.tags).intersection(projectTags).count
                return (item, overlap)
            }

            // Sort by score descending, take top N
            scored.sort { $0.score > $1.score }
            let topPicks = scored.prefix(maxPerProject).filter { $0.score > 0 }

            // If we didn't find any tag-matched readings, take the first universal ones
            let picks: [(item: TipReadingItem, score: Int)]
            if topPicks.isEmpty {
                picks = Array(scored.prefix(2))
            } else {
                picks = Array(topPicks)
            }

            guard !picks.isEmpty else { continue }

            let matched = picks.map { pair in
                MatchedReading(
                    item: pair.item,
                    projectName: project.displayName,
                    projectPath: project.id,
                    score: pair.score
                )
            }

            // Mark titles as used
            for m in matched {
                usedTitles.insert(m.item.title(.en))
            }

            groups.append(ProjectReadingGroup(
                projectName: project.displayName,
                projectPath: project.id,
                readings: matched
            ))
        }

        return groups
    }
}
