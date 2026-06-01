import Foundation

// MARK: - Project Health Check System

/// A single health check rule that can be evaluated against a project.
struct ProjectHealthRule {
    let id: String
    let title: L10n
    let description: L10n              // shown when the check passes
    let missingDescription: L10n       // shown when the check fails — actionable advice
    /// Which tags this rule applies to. Empty = universal (applies to all projects).
    let appliesTo: [ProjectTag]
    /// Patterns to look for in the project path or brief. If ANY match, the check passes.
    let detectPatterns: [String]
    /// Brief keywords that also indicate the check passes.
    let detectBriefKeywords: [String]
    /// Optional reading URL for "Learn more" link on missing items.
    let learnMoreURL: String?
}

/// Result of evaluating a health rule against a specific project.
struct ProjectHealthResult: Identifiable {
    let rule: ProjectHealthRule
    let passed: Bool
    var id: String { rule.id }
}

/// All health results for one project.
struct ProjectHealthReport: Identifiable {
    let projectName: String
    let projectPath: String
    let inferredTags: Set<ProjectTag>
    let results: [ProjectHealthResult]

    var id: String { projectPath }
    var passedCount: Int { results.filter(\.passed).count }
    var totalCount: Int { results.count }
    var hasMissingItems: Bool { passedCount < totalCount }
}

// MARK: - Health Check Engine

enum ProjectHealthEngine {

    // ─── Rule Definitions ────────────────────────────────────────────

    static let allRules: [ProjectHealthRule] = [

        // ── Universal (all projects) ─────────────────────────────────
        ProjectHealthRule(
            id: "brief_written",
            title: L10n(vi: "Mô tả dự án", en: "Project brief written"),
            description: L10n(vi: "Giúp pet hiểu dự án của bạn", en: "Helps the pet understand your project"),
            missingDescription: L10n(
                vi: "Viết mô tả ngắn cho dự án — pet sẽ đưa ra lời khuyên phù hợp hơn",
                en: "Write a short project description — the pet will give more relevant advice"
            ),
            appliesTo: [],  // universal
            detectPatterns: [],
            detectBriefKeywords: [],  // checked specially — non-empty brief = pass
            learnMoreURL: nil
        ),

        // ── Swift / Apple ────────────────────────────────────────────
        ProjectHealthRule(
            id: "xctest",
            title: L10n(vi: "Unit test", en: "Unit tests"),
            description: L10n(vi: "Thư mục test đã tìm thấy", en: "Test directory found"),
            missingDescription: L10n(
                vi: "Chưa thấy test — thêm XCTest để bảo vệ code khi refactor",
                en: "No tests found — add XCTest to protect code during refactoring"
            ),
            appliesTo: [.swiftUI, .uiKit],
            detectPatterns: ["Tests", "tests", "XCTest", "xctest"],
            detectBriefKeywords: ["xctest", "unit test", "testing"],
            learnMoreURL: nil
        ),
        ProjectHealthRule(
            id: "swift_ci",
            title: L10n(vi: "CI/CD cho Swift", en: "CI/CD for Swift"),
            description: L10n(vi: "Pipeline tự động đã cấu hình", en: "Automated pipeline configured"),
            missingDescription: L10n(
                vi: "Chưa có CI/CD — Xcode Cloud giúp deploy TestFlight tự động",
                en: "No CI/CD detected — Xcode Cloud automates TestFlight builds"
            ),
            appliesTo: [.swiftUI, .uiKit],
            detectPatterns: [".github/workflows", "xcode-cloud", "fastlane", "Fastfile", ".gitlab-ci"],
            detectBriefKeywords: ["ci/cd", "xcode cloud", "fastlane", "github actions"],
            learnMoreURL: "https://developer.apple.com/xcode-cloud/"
        ),
        ProjectHealthRule(
            id: "accessibility",
            title: L10n(vi: "Accessibility", en: "Accessibility"),
            description: L10n(vi: "Đã cân nhắc hỗ trợ VoiceOver", en: "VoiceOver support considered"),
            missingDescription: L10n(
                vi: "Thêm accessibilityLabel cho các view SwiftUI quan trọng",
                en: "Add accessibilityLabel to key SwiftUI views"
            ),
            appliesTo: [.swiftUI, .uiKit, .mobile],
            detectPatterns: ["accessibilityLabel", "accessibility", "a11y"],
            detectBriefKeywords: ["accessibility", "voiceover", "a11y"],
            learnMoreURL: "https://developer.apple.com/design/human-interface-guidelines/accessibility"
        ),
        ProjectHealthRule(
            id: "firebase_rules",
            title: L10n(vi: "Firebase Security Rules", en: "Firebase Security Rules"),
            description: L10n(vi: "Đã cấu hình quy tắc bảo mật", en: "Security rules configured"),
            missingDescription: L10n(
                vi: "Kiểm tra security rules — mặc định Firestore cho phép tất cả",
                en: "Review security rules — Firestore defaults allow everything"
            ),
            appliesTo: [.firebase],
            detectPatterns: ["firestore.rules", "firebase.json", "security-rules"],
            detectBriefKeywords: ["security rules", "firestore rules"],
            learnMoreURL: "https://firebase.google.com/docs/firestore/security/get-started"
        ),

        // ── Web Frontend ─────────────────────────────────────────────
        ProjectHealthRule(
            id: "frontend_tests",
            title: L10n(vi: "Test frontend", en: "Frontend tests"),
            description: L10n(vi: "Framework test đã cấu hình", en: "Test framework configured"),
            missingDescription: L10n(
                vi: "Thêm Jest hoặc Vitest để test component",
                en: "Add Jest or Vitest for component testing"
            ),
            appliesTo: [.react, .vue, .angular],
            detectPatterns: ["jest.config", "vitest.config", ".test.", ".spec.", "testing-library"],
            detectBriefKeywords: ["jest", "vitest", "testing-library", "cypress"],
            learnMoreURL: "https://testing-library.com/docs/guiding-principles"
        ),
        ProjectHealthRule(
            id: "linting",
            title: L10n(vi: "Linter / Formatter", en: "Linter / Formatter"),
            description: L10n(vi: "ESLint hoặc Prettier đã cấu hình", en: "ESLint or Prettier configured"),
            missingDescription: L10n(
                vi: "Thêm ESLint + Prettier để giữ code nhất quán",
                en: "Add ESLint + Prettier for consistent code style"
            ),
            appliesTo: [.react, .vue, .angular, .nodeBackend],
            detectPatterns: [".eslintrc", "eslint.config", ".prettierrc", "prettier.config", "biome.json"],
            detectBriefKeywords: ["eslint", "prettier", "biome", "linting"],
            learnMoreURL: nil
        ),
        ProjectHealthRule(
            id: "typescript",
            title: L10n(vi: "TypeScript", en: "TypeScript"),
            description: L10n(vi: "Type safety đã bật", en: "Type safety enabled"),
            missingDescription: L10n(
                vi: "Cân nhắc dùng TypeScript — bắt lỗi sớm hơn, IDE hỗ trợ tốt hơn",
                en: "Consider TypeScript — catch bugs earlier, better IDE support"
            ),
            appliesTo: [.react, .vue, .nodeBackend],
            detectPatterns: ["tsconfig.json", ".ts", ".tsx"],
            detectBriefKeywords: ["typescript"],
            learnMoreURL: nil
        ),

        // ── Backend ──────────────────────────────────────────────────
        ProjectHealthRule(
            id: "api_docs",
            title: L10n(vi: "Tài liệu API", en: "API documentation"),
            description: L10n(vi: "OpenAPI hoặc GraphQL schema có sẵn", en: "OpenAPI or GraphQL schema found"),
            missingDescription: L10n(
                vi: "Thêm OpenAPI spec hoặc GraphQL schema cho tài liệu API",
                en: "Add OpenAPI spec or GraphQL schema for API documentation"
            ),
            appliesTo: [.api, .nodeBackend, .goLang, .python],
            detectPatterns: ["openapi", "swagger", "schema.graphql", "api-docs"],
            detectBriefKeywords: ["openapi", "swagger", "graphql schema", "api doc"],
            learnMoreURL: "https://swagger.io/specification/"
        ),
        ProjectHealthRule(
            id: "backend_tests",
            title: L10n(vi: "Test backend", en: "Backend tests"),
            description: L10n(vi: "Framework test đã cấu hình", en: "Test framework configured"),
            missingDescription: L10n(
                vi: "Thêm test cho API endpoint — tránh regression khi refactor",
                en: "Add API endpoint tests — prevent regressions during refactoring"
            ),
            appliesTo: [.nodeBackend, .goLang, .python],
            detectPatterns: ["jest.config", "pytest", "go test", "_test.go", ".test.", ".spec.", "mocha"],
            detectBriefKeywords: ["jest", "pytest", "mocha", "test"],
            learnMoreURL: nil
        ),

        // ── Infrastructure ───────────────────────────────────────────
        ProjectHealthRule(
            id: "docker",
            title: L10n(vi: "Container hóa", en: "Containerization"),
            description: L10n(vi: "Dockerfile đã tìm thấy", en: "Dockerfile found"),
            missingDescription: L10n(
                vi: "Thêm Dockerfile để đóng gói và deploy nhất quán",
                en: "Add a Dockerfile for consistent packaging and deployment"
            ),
            appliesTo: [.nodeBackend, .goLang, .python],
            detectPatterns: ["Dockerfile", "docker-compose", "docker"],
            detectBriefKeywords: ["docker", "container"],
            learnMoreURL: "https://docs.docker.com/get-started/"
        ),
        ProjectHealthRule(
            id: "ci_pipeline",
            title: L10n(vi: "CI/CD pipeline", en: "CI/CD pipeline"),
            description: L10n(vi: "Pipeline tự động đã cấu hình", en: "Automated pipeline configured"),
            missingDescription: L10n(
                vi: "Thêm GitHub Actions hoặc GitLab CI để tự động test và deploy",
                en: "Add GitHub Actions or GitLab CI for automated test and deploy"
            ),
            appliesTo: [.nodeBackend, .goLang, .python, .react, .vue, .angular],
            detectPatterns: [".github/workflows", ".gitlab-ci", "Jenkinsfile", "circleci"],
            detectBriefKeywords: ["ci/cd", "github actions", "gitlab ci", "jenkins"],
            learnMoreURL: "https://docs.github.com/en/actions/learn-github-actions"
        ),
        ProjectHealthRule(
            id: "env_management",
            title: L10n(vi: "Quản lý biến môi trường", en: "Environment management"),
            description: L10n(vi: ".env.example hoặc config pattern có sẵn", en: ".env.example or config pattern found"),
            missingDescription: L10n(
                vi: "Thêm .env.example để đồng đội biết cần config gì",
                en: "Add .env.example so teammates know what config is needed"
            ),
            appliesTo: [.nodeBackend, .react, .vue, .python],
            detectPatterns: [".env.example", ".env.sample", "config.yaml", "config.toml"],
            detectBriefKeywords: [".env", "environment variable", "config"],
            learnMoreURL: nil
        ),

        // ── Database ─────────────────────────────────────────────────
        ProjectHealthRule(
            id: "db_migrations",
            title: L10n(vi: "Database migration", en: "Database migrations"),
            description: L10n(vi: "Migration framework đã cấu hình", en: "Migration framework configured"),
            missingDescription: L10n(
                vi: "Dùng migration để quản lý schema thay đổi — tránh sửa DB trực tiếp",
                en: "Use migrations to manage schema changes — avoid manual DB edits"
            ),
            appliesTo: [.database],
            detectPatterns: ["migrations", "prisma", "knex", "sequelize", "alembic", "flyway"],
            detectBriefKeywords: ["migration", "prisma", "knex", "alembic"],
            learnMoreURL: nil
        ),
    ]

    // ─── Evaluation ──────────────────────────────────────────────────

    /// Evaluate all applicable health rules for a project.
    static func evaluate(project: Project) -> ProjectHealthReport {
        let tags = ProjectSignals.inferTags(from: project.id, brief: project.brief)

        // Filter rules to those that apply to this project's tags
        let applicable = allRules.filter { rule in
            if rule.appliesTo.isEmpty { return true }  // universal
            return !Set(rule.appliesTo).intersection(tags).isEmpty
        }

        let results = applicable.map { rule -> ProjectHealthResult in
            let passed = evaluateRule(rule, projectPath: project.id, brief: project.brief)
            return ProjectHealthResult(rule: rule, passed: passed)
        }

        // Sort: missing items first, then passed
        let sorted = results.sorted { !$0.passed && $1.passed }

        return ProjectHealthReport(
            projectName: project.displayName,
            projectPath: project.id,
            inferredTags: tags,
            results: sorted
        )
    }

    /// Evaluate all projects and return reports sorted by most recent.
    static func evaluateAll(projects: [String: Project]) -> [ProjectHealthReport] {
        let sorted = projects.values.sorted { $0.lastSeenAt > $1.lastSeenAt }
        return sorted.map { evaluate(project: $0) }
    }

    private static func evaluateRule(_ rule: ProjectHealthRule, projectPath: String, brief: String) -> Bool {
        // Special case: brief_written checks if the brief is non-empty
        if rule.id == "brief_written" {
            return !brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let pathLower = projectPath.lowercased()
        let briefLower = brief.lowercased()

        // Check path patterns
        for pattern in rule.detectPatterns {
            if pathLower.contains(pattern.lowercased()) { return true }
        }

        // Check brief keywords
        for keyword in rule.detectBriefKeywords {
            if briefLower.contains(keyword.lowercased()) { return true }
        }

        return false
    }
}
