import Foundation
import Combine

@MainActor
final class ReflectionComposition: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()

    let eventStore: ReflectionEventStore
    let narrativeStore: NarrativeStore
    let summaryStore: SessionSummaryStore
    let enricher: NarrativeEnricher

    init(language: String = "vi") {
        let events = ReflectionEventStore()
        let narratives = NarrativeStore()
        let summaries = SessionSummaryStore()
        let api = ReflectionAPIClient()
        self.eventStore = events
        self.narrativeStore = narratives
        self.summaryStore = summaries
        self.enricher = NarrativeEnricher(api: api, store: narratives, language: language)
    }

    func start() {
        eventStore.start()
        narrativeStore.start()
        summaryStore.start()
        #if DEBUG
        ReflectionMockSeeder.seed(into: self)
        #endif
    }
}
