import Foundation
import Combine
import os

/// Polls ~/.codepet/events.jsonl (written by Claude Code hooks) and exposes
/// captured decision moments to the Reflection tab.
///
/// On app launch the store reads from the start of the file so prior
/// sessions remain visible across restarts. The in-memory list is capped at
/// `maxRetainedEvents` so very large historical files don't bloat memory.
///
/// Spec: docs/superpowers/specs/2026-05-04-claude-code-reflection-logging-design.md
@MainActor
final class ReflectionEventStore: ObservableObject {

    @Published private(set) var events: [CapturedEvent] = []

    /// Raw JSONL event tuples exposed for TurnAssembler — preserves type and full ISO time.
    @Published private(set) var rawJSONLEvents: [(type: String, isoTime: String, sessionId: String, text: String)] = []

    private let logURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codepet/events.jsonl")
    private let pollInterval: TimeInterval = 1.5
    private let maxRetainedEvents = 500

    private var pollTimer: Timer?
    private var readOffset: UInt64 = 0
    private var lineBuffer = ""
    private let logger = Logger(subsystem: "app.murror.codepet", category: "Reflection")

    func start() {
        ensureFileExists()
        // Read from offset 0 so historical events (sessions, turns, summaries)
        // from prior app launches are restored. NarrativeStore /
        // SessionSummaryStore / SessionEndStore all do the same. The
        // `maxRetainedEvents` cap below trims the in-memory window if the
        // file is very large.
        readOffset = 0
        events.removeAll()
        rawJSONLEvents.removeAll()
        lineBuffer = ""
        pollTimer?.invalidate()
        readNewLines()  // ingest the existing backlog synchronously on launch
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readNewLines() }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Inject mock events for UI testing — appends to in-memory rawJSONLEvents
    /// without touching the events.jsonl file. Cleared on app relaunch.
    func seedMockEvents(_ entries: [(type: String, isoTime: String, sessionId: String, text: String)]) {
        rawJSONLEvents.append(contentsOf: entries)
    }

    /// Live events grouped into a `ReflectionSession` for the sidebar.
    /// Returns nil until at least one event has been captured this app session.
    var liveSession: ReflectionSession? {
        guard !events.isEmpty else { return nil }
        let day = ReflectionDay(
            label: "Live",
            dateDisplay: liveDateDisplay(),
            captured: events.count,
            decisions: events.count,
            risks: 0,
            events: events.reversed(),  // most recent first
            patterns: [],
            prompt: ReflectionPrompt(
                headline: "Live capture from Claude Code.",
                body: "Decision moments from your current session land here as you work. Patterns and reflection text fill in over time.",
                probe: "Notice anything in this list you'd revisit later?",
                sourceCitation: "Based on \(events.count) captures · live"
            )
        )
        return ReflectionSession(day: day, dateGroup: "Today (live)", source: .claudeCode)
    }

    // MARK: - File I/O

    private func ensureFileExists() {
        let dir = logURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }

    private func currentFileSize() -> UInt64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path)
        return (attrs?[.size] as? UInt64) ?? 0
    }

    private func readNewLines() {
        let size = currentFileSize()
        if size < readOffset {
            // File rotated or cleared — replay from start.
            readOffset = 0
            lineBuffer = ""
        }
        guard size > readOffset else { return }

        guard let handle = try? FileHandle(forReadingFrom: logURL) else { return }
        defer { try? handle.close() }

        do { try handle.seek(toOffset: readOffset) } catch {
            logger.warning("seek failed: \(error.localizedDescription)")
            return
        }

        guard let chunk = try? handle.readToEnd(), !chunk.isEmpty else { return }
        readOffset += UInt64(chunk.count)

        guard let text = String(data: chunk, encoding: .utf8) else { return }
        lineBuffer.append(text)

        var lines = lineBuffer.components(separatedBy: "\n")
        let trailing = lines.removeLast()
        lineBuffer = trailing

        var newEvents: [CapturedEvent] = []
        let decoder = JSONDecoder()
        for line in lines where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let raw = try? decoder.decode(JSONLEvent.self, from: data) else {
                logger.warning("skipping malformed line")
                continue
            }
            newEvents.append(raw.toCapturedEvent())
            rawJSONLEvents.append((
                type: raw.type,
                isoTime: raw.time,
                sessionId: raw.session_id ?? "",
                text: raw.text
            ))
        }

        if !newEvents.isEmpty {
            events.append(contentsOf: newEvents)
            if events.count > maxRetainedEvents {
                events.removeFirst(events.count - maxRetainedEvents)
            }
        }
    }

    private func liveDateDisplay() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE · MMMM d"
        return fmt.string(from: Date())
    }
}

// MARK: - JSONL line schema

private struct JSONLEvent: Decodable {
    let time: String
    let type: String
    let session_id: String?
    let cwd: String?
    let text: String
    let tool_name: String?
    let path: String?

    func toCapturedEvent() -> CapturedEvent {
        CapturedEvent(
            time: Self.formatHHmm(time),
            isoTime: time,
            source: .claudeCode,
            text: text,
            aiSummary: nil,
            trigger: nil,
            context: nil,
            isManualLog: false
        )
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static func formatHHmm(_ iso: String) -> String {
        guard let date = isoFormatter.date(from: iso) else { return iso }
        return displayFormatter.string(from: date)
    }
}
