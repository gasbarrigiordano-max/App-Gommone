import WidgetKit
import SwiftUI

/// Punto d'ingresso della Widget Extension. Da aggiungere come nuovo target Xcode
/// "Widget Extension" (con "Include Live Activity" spuntato) chiamato TripActivityWidget:
/// vedi ios-app/README.md per i passaggi esatti in Xcode.
@main
struct TripActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        TripActivityWidgetLiveActivity()
    }
}
