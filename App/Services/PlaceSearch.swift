import Foundation
import MapKit

/// Address autocomplete backed by MKLocalSearchCompleter.
@Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet { completer.queryFragment = query }
    }
    private(set) var results: [MKLocalSearchCompletion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(6))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        results = []
    }

    /// Looks up a completion's coordinate. Returns nil if it can't be found.
    func resolve(_ completion: MKLocalSearchCompletion) async -> (coordinate: CLLocationCoordinate2D, address: String)? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        let address = [completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        return (item.location.coordinate, address)
    }
}
