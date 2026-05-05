import Foundation
import CryptoKit

/// Input to the assembler. Source events from `events.jsonl` and `narratives.jsonl`
/// are converted to this shape before assembly so the assembler stays pure.
struct AssemblerInput {
    enum Kind {
        case prompt(text: String)
        case tool(text: String)
        case summary(text: String)
    }
    let kind: Kind
    let isoTime: String           // raw ISO 8601 — used for turn_id
    let sessionId: String
}

enum TurnAssembler {

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Group inputs into Turns. Pure — no I/O.
    static func assemble(
        inputs: [AssemblerInput],
        now: Date,
        narratives: [String: Narrative]
    ) -> [Turn] {
        let sorted = inputs.sorted { lhs, rhs in
            if lhs.sessionId != rhs.sessionId { return lhs.sessionId < rhs.sessionId }
            return lhs.isoTime < rhs.isoTime
        }

        var turns: [Turn] = []
        var sessionGroups: [String: [AssemblerInput]] = [:]
        for input in sorted { sessionGroups[input.sessionId, default: []].append(input) }

        for (sessionId, events) in sessionGroups {
            turns.append(contentsOf: assembleSession(
                sessionId: sessionId,
                events: events,
                now: now,
                narratives: narratives
            ))
        }

        return turns.sorted { $0.startedAt > $1.startedAt }
    }

    private static func assembleSession(
        sessionId: String,
        events: [AssemblerInput],
        now: Date,
        narratives: [String: Narrative]
    ) -> [Turn] {
        var turns: [Turn] = []

        // Drop summary events that arrive before any prompt.
        var pendingPrompt: AssemblerInput? = nil
        var pendingTools: [AssemblerInput] = []

        func flushAsOrphan() {
            guard let prompt = pendingPrompt,
                  case .prompt(let text) = prompt.kind,
                  let started = isoFormatter.date(from: prompt.isoTime) else { return }
            turns.append(makeTurn(
                prompt: text,
                started: started,
                ended: nil,
                tools: pendingTools,
                sessionId: sessionId,
                promptISO: prompt.isoTime,
                narratives: narratives,
                forceState: .pendingOrphan
            ))
            pendingPrompt = nil
            pendingTools = []
        }

        for input in events {
            switch input.kind {
            case .prompt:
                if pendingPrompt != nil {
                    flushAsOrphan()  // previous prompt orphaned by new prompt
                }
                pendingPrompt = input
                pendingTools = []
            case .tool:
                if pendingPrompt != nil { pendingTools.append(input) }
            case .summary:
                guard let prompt = pendingPrompt,
                      case .prompt(let promptText) = prompt.kind,
                      let started = isoFormatter.date(from: prompt.isoTime),
                      let ended = isoFormatter.date(from: input.isoTime) else { continue }
                turns.append(makeTurn(
                    prompt: promptText,
                    started: started,
                    ended: ended,
                    tools: pendingTools,
                    sessionId: sessionId,
                    promptISO: prompt.isoTime,
                    narratives: narratives,
                    forceState: nil
                ))
                pendingPrompt = nil
                pendingTools = []
            }
        }

        // Trailing prompt with no summary
        if let prompt = pendingPrompt,
           case .prompt(let text) = prompt.kind,
           let started = isoFormatter.date(from: prompt.isoTime) {
            let age = now.timeIntervalSince(started)
            // Spec: trailing prompts older than 30 minutes (wall clock) become orphans.
            // Threshold is strict — exactly 30:00 stays pending; >30:00 becomes orphan.
            let orphanThreshold: TimeInterval = 30 * 60
            let state: TurnState = age > orphanThreshold ? .pendingOrphan : .pending
            turns.append(makeTurn(
                prompt: text,
                started: started,
                ended: nil,
                tools: pendingTools,
                sessionId: sessionId,
                promptISO: prompt.isoTime,
                narratives: narratives,
                forceState: state
            ))
        }

        return turns
    }

    private static func makeTurn(
        prompt: String,
        started: Date,
        ended: Date?,
        tools: [AssemblerInput],
        sessionId: String,
        promptISO: String,
        narratives: [String: Narrative],
        forceState: TurnState?
    ) -> Turn {
        let id = Turn.makeID(sessionId: sessionId, promptISO: promptISO)
        let narrative = narratives[id]

        let state: TurnState
        if let forced = forceState {
            state = forced
        } else if narrative != nil {
            state = .ready
        } else if ended != nil {
            state = .summarizing
        } else {
            state = .pending
        }

        let rawEvents: [CapturedEvent] = tools.map { input in
            let displayTime = displayHHmm(input.isoTime)
            let text: String
            if case .tool(let t) = input.kind { text = t } else { text = "" }
            let seed = "\(sessionId)|\(input.isoTime)|\(text)"
            return CapturedEvent(
                id: deterministicID(seed: seed),
                time: displayTime,
                source: .claudeCode,
                text: text,
                sessionId: sessionId
            )
        }

        return Turn(
            id: id,
            sessionId: sessionId,
            startedAt: started,
            endedAt: ended,
            prompt: prompt,
            rawEvents: rawEvents,
            narrative: narrative,
            state: state
        )
    }

    private static func deterministicID(seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func displayHHmm(_ iso: String) -> String {
        guard let date = isoFormatter.date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
