import XCTest
@testable import codepet

@MainActor
final class TipsPersistenceTests: XCTestCase {

    private let persistence = TipsPersistence.shared

    override func setUp() async throws {
        // Start each test with a clean slate
        persistence.resetAll()
    }

    override func tearDown() async throws {
        persistence.resetAll()
    }

    // MARK: - Round-trip

    func testSaveAndLoadSkillProgress() {
        let original = TipsState()
        for _ in 0..<3 { original.recordPractice(for: "nova", index: 0) }
        for _ in 0..<5 { original.recordPractice(for: "nova", index: 1) }
        persistence.save(original)

        let restored = TipsState()
        persistence.load(into: restored)

        XCTAssertEqual(restored.progress(for: "nova", index: 0).practiceCount, 3)
        XCTAssertEqual(restored.progress(for: "nova", index: 1).practiceCount, 5)
        XCTAssertTrue(restored.progress(for: "nova", index: 1).isMastered)
    }

    func testSaveAndLoadGuidance() {
        let original = TipsState()
        original.currentGuidance = GuidanceResult(
            headline: "Test headline",
            body: "Test body",
            actionLabel: "Try it",
            mood: "excited",
            sourcePatterns: ["pattern1", "pattern2"],
            expertQuote: nil,
            expertName: nil,
            generatedAt: Date()
        )
        persistence.save(original)

        let restored = TipsState()
        persistence.load(into: restored)

        XCTAssertEqual(restored.currentGuidance?.headline, "Test headline")
        XCTAssertEqual(restored.currentGuidance?.mood, "excited")
        XCTAssertEqual(restored.currentGuidance?.sourcePatterns.count, 2)
    }

    func testSaveAndLoadSetupActions() {
        let original = TipsState()
        original.markSetupCompleted(petId: "crash", index: 0)
        original.markSetupCompleted(petId: "crash", index: 2)
        persistence.save(original)

        let restored = TipsState()
        persistence.load(into: restored)

        XCTAssertTrue(restored.isSetupCompleted(petId: "crash", index: 0))
        XCTAssertFalse(restored.isSetupCompleted(petId: "crash", index: 1))
        XCTAssertTrue(restored.isSetupCompleted(petId: "crash", index: 2))
    }

    func testSaveAndLoadDismissedDates() {
        let original = TipsState()
        original.dismissGuidance()  // adds today's key
        persistence.save(original)

        let restored = TipsState()
        persistence.load(into: restored)

        XCTAssertTrue(restored.isGuidanceDismissed)
    }

    func testLoadWithNoSavedDataIsNoop() {
        let state = TipsState()
        state.recordPractice(for: "byte", index: 0)
        persistence.load(into: state)
        // Should NOT overwrite existing state when nothing was saved
        XCTAssertEqual(state.progress(for: "byte", index: 0).practiceCount, 1)
    }

    func testResetClearsAll() {
        let state = TipsState()
        for _ in 0..<5 { state.recordPractice(for: "nova", index: 0) }
        state.markSetupCompleted(petId: "nova", index: 1)
        persistence.save(state)
        persistence.resetAll()

        let restored = TipsState()
        persistence.load(into: restored)

        XCTAssertEqual(restored.progress(for: "nova", index: 0).practiceCount, 0)
        XCTAssertFalse(restored.isSetupCompleted(petId: "nova", index: 1))
    }

    func testNilGuidanceSurvivesRoundTrip() {
        let original = TipsState()
        original.currentGuidance = nil
        persistence.save(original)

        let restored = TipsState()
        persistence.load(into: restored)

        XCTAssertNil(restored.currentGuidance)
    }
}
