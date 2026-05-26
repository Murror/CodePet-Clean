import Foundation

/// A detected project, identified by its root directory path.
/// Projects are auto-detected from the `cwd` field in JSONL events.
struct Project: Identifiable, Hashable, Codable {
    /// Unique identifier — the normalized absolute path of the project root.
    let id: String              // e.g. "/Users/mona/Projects/codepet"

    /// Human-readable display name derived from the folder name.
    var displayName: String     // e.g. "codepet"

    /// Optional user-provided brief describing the project.
    var brief: String

    /// When this project was first seen.
    let firstSeenAt: Date

    /// Last time an event from this project was observed.
    var lastSeenAt: Date

    /// Derives a display name from a path by taking the last path component.
    static func nameFromPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        return name.isEmpty ? path : name
    }
}
