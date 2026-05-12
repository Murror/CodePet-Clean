import Foundation
import Combine

/// Drives the "Sprout × Byte" hardcoded demo. Pure state — no I/O, no API
/// calls. Hotkey input drives the methods on this controller, and the
/// Reflection tab renders from its @Published state.
@MainActor
final class DemoScriptController: ObservableObject {

    @Published private(set) var firedMilestones: [DemoScript.Milestone] = []
    @Published private(set) var reflectionRevealed: Bool = false
    @Published private(set) var sessionStartedAt: Date? = nil

    func startSession(now: Date = Date()) {
        sessionStartedAt = now
        firedMilestones = []
        reflectionRevealed = false
    }

    func fireMilestone(index: Int) {
        guard sessionStartedAt != nil else { return }
        guard let milestone = DemoScript.milestones.first(where: { $0.index == index }) else { return }
        guard !firedMilestones.contains(where: { $0.index == index }) else { return }
        firedMilestones.append(milestone)
    }

    func revealReflection() {
        guard sessionStartedAt != nil else { return }
        reflectionRevealed = true
    }

    func reset() {
        firedMilestones = []
        reflectionRevealed = false
        sessionStartedAt = nil
    }

    /// "Panic" skip: forces all 4 milestones to be fired + reveals the
    /// reflection. Bound to ⌥0 for safety during live demo if something
    /// gets out of order.
    func panicSkip() {
        if sessionStartedAt == nil { startSession() }
        for milestone in DemoScript.milestones {
            if !firedMilestones.contains(where: { $0.index == milestone.index }) {
                firedMilestones.append(milestone)
            }
        }
        reflectionRevealed = true
    }

    // MARK: - Synthesized production-shape data

    /// Synthesizes a `Session` (with Turns, Narratives, optional summary) from
    /// the current demo state, shaped exactly like a production session so the
    /// existing ReflectionTab UI renders it without any branching.
    /// Returns nil before `startSession()` is called.
    var demoSession: Session? {
        guard let start = sessionStartedAt else { return nil }

        let turns: [Turn] = firedMilestones.map { milestone in
            let turnTime = start.addingTimeInterval(
                TimeInterval(milestone.offsetMinutesFromStart * 60)
            )
            let narrative = Narrative(
                title: milestone.sidebarLabel,
                whatYouWanted: milestone.whatYouWanted,
                whatHappened: milestone.whatHappened,
                lesson: milestone.lesson,
                model: "demo",
                generatedAt: turnTime,
                schemaVersion: 1
            )
            return Turn(
                id: "\(DemoScript.sessionId):turn-\(milestone.index)",
                sessionId: DemoScript.sessionId,
                startedAt: turnTime,
                endedAt: turnTime.addingTimeInterval(60),
                prompt: milestone.prompt,
                rawEvents: [],
                narrative: narrative,
                state: .ready
            )
        }

        let summary: SessionSummary? = reflectionRevealed
            ? SessionSummary(
                sessionId: DemoScript.sessionId,
                summary: DemoScript.reflectionSummary,
                lesson: DemoScript.reflectionSessionLesson,
                generatedAt: Date(),
                model: "demo",
                schemaVersion: 1
            )
            : nil

        return Session(
            id: DemoScript.sessionId,
            turns: turns,
            startedAt: start,
            endedAt: nil,
            summary: summary
        )
    }
}
