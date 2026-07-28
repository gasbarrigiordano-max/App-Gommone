import ActivityKit
import Foundation

/// Attributi della Live Activity "uscita in corso". Questo file va incluso in ENTRAMBI i
/// target Xcode — App e TripActivityWidget — altrimenti uno dei due non compila (il plugin
/// nella app e la UI nella widget extension referenziano lo stesso tipo).
/// In Xcode: seleziona il file, pannello "File Inspector" a destra, spunta entrambi i target
/// sotto "Target Membership".
@available(iOS 16.1, *)
public struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var speedKn: Double
        public var distanceNm: Double
        public var elapsedSeconds: Int
        public var fuelLiters: Double

        public init(speedKn: Double, distanceNm: Double, elapsedSeconds: Int, fuelLiters: Double) {
            self.speedKn = speedKn
            self.distanceNm = distanceNm
            self.elapsedSeconds = elapsedSeconds
            self.fuelLiters = fuelLiters
        }
    }

    public var startedAt: Date

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}
