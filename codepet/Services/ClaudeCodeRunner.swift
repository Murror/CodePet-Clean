import Foundation
import Combine

/// Runs the user's locally-installed `claude` CLI headless and streams its
/// output back into the app as structured events.
///
/// PLAN-USAGE NOTE: this deliberately drives the user's *own* `claude` binary
/// (via a login shell so their PATH + auth resolve). The heavy code generation
/// therefore runs on the Claude subscription the user already pays for — Codepet
/// adds no separate API key and no extra billing. Coaching commentary is derived
/// from the events below WITHOUT extra model calls (see ExercisePetCoach).
///
/// The app is not sandboxed (com.apple.security.app-sandbox = false), so spawning
/// a subprocess is permitted. This is the first process Codepet spawns.
final class ClaudeCodeRunner: ObservableObject {

    // MARK: - Types

    enum RunState: Equatable {
        case idle
        case running
        case finished(exitCode: Int32)
        case failed(reason: String)
    }

    struct StreamEvent: Identifiable, Equatable {
        enum Kind: Equatable {
            case system          // session init / meta
            case assistantText   // Claude's prose
            case toolUse         // Claude invoked a tool (Edit/Write/Bash/...)
            case toolResult      // result of a tool call
            case result          // final summary line
        }
        let id = UUID()
        let kind: Kind
        let toolName: String?    // "Edit", "Write", "Bash", "Read", ...
        let filePath: String?    // file the tool touched, when applicable
        let text: String         // human-readable line
        let time: Date = Date()

        static func == (l: StreamEvent, r: StreamEvent) -> Bool { l.id == r.id }
    }

    // MARK: - Published state

    @Published private(set) var state: RunState = .idle
    @Published private(set) var events: [StreamEvent] = []
    /// Distinct file paths Claude Code edited/created this run, in first-seen order.
    @Published private(set) var touchedFiles: [String] = []

    var isRunning: Bool { if case .running = state { return true }; return false }

    // MARK: - Private

    private var process: Process?
    private var stdoutBuffer = Data()
    private let queue = DispatchQueue(label: "app.murror.codepet.claude-runner")
    /// Last assistant prose we emitted. `stream-json` repeats the final message
    /// inside the terminal `result` event, so we use this to skip the echo.
    private var lastAssistantText = ""

    // Login shells to try, in order. `-l` loads the user's profile so `claude`
    // (commonly at ~/.claude/local, /opt/homebrew/bin, /usr/local/bin, or an
    // npm global) is on PATH even though the app was launched from Finder.
    private static let loginShells = ["/bin/zsh", "/bin/bash"]

    // MARK: - API

    /// Spawn `claude` in print mode against `projectDir`, streaming events.
    /// - Parameters:
    ///   - prompt: the exercise prompt (passed via stdin to avoid quoting issues).
    ///   - projectDir: absolute path to the user's project (working directory).
    ///   - allowedTools: tools Claude may use; keeps the run scoped.
    ///   - maxTurns: hard cap so a stuck run can't keep consuming the user's plan.
    func run(prompt: String,
             projectDir: String,
             allowedTools: [String] = ["Edit", "Write", "Read", "Bash", "Glob", "Grep"],
             maxTurns: Int = 8) {

        guard !isRunning else { return }

        // Reset
        stdoutBuffer.removeAll()
        events.removeAll()
        touchedFiles.removeAll()
        lastAssistantText = ""
        state = .running

        var dir = projectDir
        if dir.hasPrefix("~") {
            dir = (dir as NSString).expandingTildeInPath
        }
        guard FileManager.default.fileExists(atPath: dir) else {
            state = .failed(reason: "Project folder not found: \(dir)")
            return
        }

        let shell = Self.loginShells.first { FileManager.default.fileExists(atPath: $0) } ?? "/bin/zsh"

        // Build the claude invocation. Prompt comes from stdin (no arg quoting).
        let toolsArg = allowedTools.joined(separator: ",")
        let claudeCmd = """
        claude -p \
        --output-format stream-json \
        --verbose \
        --max-turns \(maxTurns) \
        --allowedTools "\(toolsArg)" \
        --add-dir "\(dir)"
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-lc", claudeCmd]
        proc.currentDirectoryURL = URL(fileURLWithPath: dir)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        proc.standardInput = stdinPipe

        // Stream stdout line-by-line as it arrives.
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.queue.async { self?.ingest(chunk) }
        }

        proc.terminationHandler = { [weak self] p in
            // Drain any trailing buffered line.
            self?.queue.async {
                self?.flushTrailing()
                let code = p.terminationStatus
                DispatchQueue.main.async {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    // Surface stderr only if claude failed outright (e.g. not installed).
                    if code != 0 && self?.events.isEmpty == true {
                        let err = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                                         encoding: .utf8) ?? ""
                        self?.state = .failed(reason: Self.friendlyError(err, exitCode: code))
                    } else {
                        self?.state = .finished(exitCode: code)
                    }
                }
            }
        }

        do {
            try proc.run()
            self.process = proc
            // Feed the prompt to claude's stdin, then close it.
            if let data = (prompt + "\n").data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
            stdinPipe.fileHandleForWriting.closeFile()
        } catch {
            state = .failed(reason: "Couldn't launch claude: \(error.localizedDescription)")
        }
    }

    /// Terminate the current run (e.g. user tapped Stop, or left the exercise).
    func cancel() {
        process?.terminate()
        process = nil
        if isRunning { state = .finished(exitCode: -1) }
    }

    // MARK: - Stream parsing

    private func ingest(_ chunk: Data) {
        stdoutBuffer.append(chunk)
        // Split on newlines; keep the trailing partial line in the buffer.
        while let nl = stdoutBuffer.firstIndex(of: 0x0A) {
            let lineData = stdoutBuffer.subdata(in: stdoutBuffer.startIndex..<nl)
            stdoutBuffer.removeSubrange(stdoutBuffer.startIndex...nl)
            parseLine(lineData)
        }
    }

    private func flushTrailing() {
        guard !stdoutBuffer.isEmpty else { return }
        let lineData = stdoutBuffer
        stdoutBuffer.removeAll()
        parseLine(lineData)
    }

    private func parseLine(_ data: Data) {
        guard !data.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let type = obj["type"] as? String ?? ""
        switch type {
        case "system":
            // init/meta — keep it quiet; emit nothing user-facing.
            break

        case "assistant":
            if let message = obj["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for item in content { handleAssistantContent(item) }
            }

        case "user":
            // Tool results arrive as user-role messages with tool_result content.
            if let message = obj["message"] as? [String: Any],
               let content = message["content"] as? [[String: Any]] {
                for item in content where (item["type"] as? String) == "tool_result" {
                    let text = Self.flatten(item["content"])
                    emit(.init(kind: .toolResult, toolName: nil, filePath: nil,
                               text: text.isEmpty ? "(done)" : text))
                }
            }

        case "result":
            let summary = (obj["result"] as? String) ?? "Run complete."
            // `stream-json` repeats the final assistant message here. If we already
            // showed it as prose, don't echo it a second time.
            if summary.trimmingCharacters(in: .whitespacesAndNewlines) == lastAssistantText {
                break
            }
            emit(.init(kind: .result, toolName: nil, filePath: nil, text: summary))

        default:
            break
        }
    }

    private func handleAssistantContent(_ item: [String: Any]) {
        switch item["type"] as? String {
        case "text":
            let t = (item["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                lastAssistantText = t
                emit(.init(kind: .assistantText, toolName: nil, filePath: nil, text: t))
            }
        case "tool_use":
            let name = item["name"] as? String
            let input = item["input"] as? [String: Any]
            let path = (input?["file_path"] as? String) ?? (input?["path"] as? String)
            let detail = Self.toolDetail(name: name, input: input, path: path)
            emit(.init(kind: .toolUse, toolName: name, filePath: path, text: detail))
            if let path, !path.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if !self.touchedFiles.contains(path) { self.touchedFiles.append(path) }
                }
            }
        default:
            break
        }
    }

    private func emit(_ event: StreamEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.events.append(event)
        }
    }

    // MARK: - Helpers

    private static func toolDetail(name: String?, input: [String: Any]?, path: String?) -> String {
        switch name {
        case "Edit", "Write", "MultiEdit":
            return "\(name == "Write" ? "Created" : "Edited") \(shortPath(path))"
        case "Bash":
            return "Ran: \((input?["command"] as? String) ?? "command")"
        case "Read":
            return "Read \(shortPath(path))"
        case "Glob", "Grep":
            return "Searched \((input?["pattern"] as? String) ?? "the project")"
        default:
            return name ?? "Tool"
        }
    }

    private static func shortPath(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "a file" }
        return (path as NSString).lastPathComponent
    }

    /// tool_result content can be a string or an array of {type,text} parts.
    private static func flatten(_ content: Any?) -> String {
        if let s = content as? String { return s }
        if let arr = content as? [[String: Any]] {
            return arr.compactMap { $0["text"] as? String }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func friendlyError(_ stderr: String, exitCode: Int32) -> String {
        let s = stderr.lowercased()
        if s.contains("command not found") || s.contains("not found") {
            return "Claude Code isn't installed or isn't on your PATH. Install it, then try again."
        }
        if s.contains("not logged in") || s.contains("authenticate") || s.contains("login") {
            return "Claude Code needs you to sign in. Run `claude` once in your terminal to log in."
        }
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "claude exited with code \(exitCode)." : trimmed
    }
}
