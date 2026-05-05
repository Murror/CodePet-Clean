import Foundation
import Combine

@MainActor
final class ReflectionComposition: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()

    let eventStore: ReflectionEventStore
    let narrativeStore: NarrativeStore
    let enricher: NarrativeEnricher

    init(language: String = "vi") {
        let events = ReflectionEventStore()
        let narratives = NarrativeStore()
        let api = ReflectionAPIClient()
        self.eventStore = events
        self.narrativeStore = narratives
        self.enricher = NarrativeEnricher(api: api, store: narratives, language: language)
    }

    func start() {
        eventStore.start()
        narrativeStore.start()
    }
}
