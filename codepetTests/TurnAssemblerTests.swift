import XCTest
@testable import codepet

final class TurnAssemblerTests: XCTestCase {
    private let session = "session-A"

    private func makeEvent(
        time: String,
        text: String,
        sessionId: String? = nil,
        source: EventSource = .claudeCode
    ) -> CapturedEvent {
        CapturedEvent(
            time: time,
            source: source,
            text: text,
            sessionId: sessionId ?? session
        )
    }

    func testSingleTurnHappyPath() {
        // prompt + 2 tools + summary -> 1 ready-shape turn
        let prompt = AssemblerInput(
            kind: .prompt(text: "fix the bug"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let tool1 = AssemblerInput(
            kind: .tool(text: "Edit"),
            isoTime: "2026-05-05T09:00:30Z",
            sessionId: session
        )
        let tool2 = AssemblerInput(
            kind: .tool(text: "Bash"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )
        let summary = AssemblerInput(
            kind: .summary(text: "Edit foo.swift · Bash: git commit"),
            isoTime: "2026-05-05T09:02:00Z",
            sessionId: session
        )

        let turns = TurnAssembler.assemble(
            inputs: [prompt, tool1, tool2, summary],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        let t = turns[0]
        XCTAssertEqual(t.sessionId, session)
        XCTAssertEqual(t.prompt, "fix the bug")
        XCTAssertEqual(t.rawEvents.count, 2)
        XCTAssertEqual(t.state, .summarizing)  // closed but no narrative
        XCTAssertNotNil(t.endedAt)
    }

    func testTwoPromptsBackToBackFirstIsOrphan() {
        let p1 = AssemblerInput(
            kind: .prompt(text: "first"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let p2 = AssemblerInput(
            kind: .prompt(text: "second"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )
        let s2 = AssemblerInput(
            kind: .summary(text: "did stuff"),
            isoTime: "2026-05-05T09:02:00Z",
            sessionId: session
        )

        let turns = TurnAssembler.assemble(
            inputs: [p1, p2, s2],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 2)
        // Sorted by startedAt descending => second prompt first
        XCTAssertEqual(turns[0].prompt, "second")
        XCTAssertEqual(turns[1].prompt, "first")
        XCTAssertEqual(turns[1].state, .pendingOrphan)
    }

    func testPromptWithNoSummaryWithin30MinutesIsOrphan() {
        let p = AssemblerInput(
            kind: .prompt(text: "abandoned"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let now = ISO8601DateFormatter().date(from: "2026-05-05T09:35:00Z")!

        let turns = TurnAssembler.assemble(
            inputs: [p],
            now: now,
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].state, .pendingOrphan)
    }

    func testPromptWithNoSummaryWithin30MinutesIsPending() {
        let p = AssemblerInput(
            kind: .prompt(text: "still going"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let now = ISO8601DateFormatter().date(from: "2026-05-05T09:10:00Z")!

        let turns = TurnAssembler.assemble(
            inputs: [p],
            now: now,
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].state, .pending)
    }

    func testSummaryBeforePromptIsIgnored() {
        let s = AssemblerInput(
            kind: .summary(text: "lost"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let p = AssemblerInput(
            kind: .prompt(text: "first prompt"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )

        let turns = TurnAssembler.assemble(
            inputs: [s, p],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertEqual(turns[0].prompt, "first prompt")
        XCTAssertEqual(turns[0].state, .pending)
    }

    func testNarrativeMergedWhenAvailable() {
        let p = AssemblerInput(
            kind: .prompt(text: "summarize me"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: session
        )
        let s = AssemblerInput(
            kind: .summary(text: "raw"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: session
        )
        let id = Turn.makeID(sessionId: session, promptISO: "2026-05-05T09:00:00Z")
        let n = Narrative(
            title: "T",
            whatYouWanted: "w",
            whatHappened: "h",
            lesson: "l",
            model: "m",
            generatedAt: Date(),
            schemaVersion: 1
        )

        let turns = TurnAssembler.assemble(
            inputs: [p, s],
            now: Date(),
            narratives: [id: n]
        )

        XCTAssertEqual(turns.count, 1)
        XCTAssertNotNil(turns[0].narrative)
        XCTAssertEqual(turns[0].state, .ready)
    }

    func testInterleavedSessionsKeptSeparate() {
        let pA = AssemblerInput(
            kind: .prompt(text: "A1"),
            isoTime: "2026-05-05T09:00:00Z",
            sessionId: "A"
        )
        let pB = AssemblerInput(
            kind: .prompt(text: "B1"),
            isoTime: "2026-05-05T09:00:30Z",
            sessionId: "B"
        )
        let sA = AssemblerInput(
            kind: .summary(text: "A done"),
            isoTime: "2026-05-05T09:01:00Z",
            sessionId: "A"
        )
        let sB = AssemblerInput(
            kind: .summary(text: "B done"),
            isoTime: "2026-05-05T09:01:30Z",
            sessionId: "B"
        )

        let turns = TurnAssembler.assemble(
            inputs: [pA, pB, sA, sB],
            now: Date(),
            narratives: [:]
        )

        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(Set(turns.map { $0.sessionId }), ["A", "B"])
        XCTAssertTrue(turns.allSatisfy { $0.state == .summarizing })
    }
}
