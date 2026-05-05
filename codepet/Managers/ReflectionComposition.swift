import Foundation
import Combine

@MainActor
final class ReflectionComposition: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()

    let eventStore: ReflectionEventStore
    let narrativeStore: NarrativeStore
    let summaryStore: SessionSummaryStore
    let endStore: SessionEndStore
    let enricher: NarrativeEnricher
    let sessionEnricher: SessionSummaryEnricher

    init(language: String = "en") {
        let events = ReflectionEventStore()
        let narratives = NarrativeStore()
        let summaries = SessionSummaryStore()
        let ends = SessionEndStore()
        let api = ReflectionAPIClient()
        self.eventStore = events
        self.narrativeStore = narratives
        self.summaryStore = summaries
        self.endStore = ends
        self.enricher = NarrativeEnricher(api: api, store: narratives, language: language)
        self.sessionEnricher = SessionSummaryEnricher(api: api, store: summaries, language: language)
    }

    func start() {
        eventStore.start()
        narrativeStore.start()
        summaryStore.start()
        endStore.start()
        #if DEBUG
        ReflectionMockSeeder.seed(into: self)
        #endif
    }
}
