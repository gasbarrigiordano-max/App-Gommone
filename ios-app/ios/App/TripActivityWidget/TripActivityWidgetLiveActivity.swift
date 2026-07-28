import ActivityKit
import WidgetKit
import SwiftUI

// Palette coerente con --navy-deep/--brass/--teal usati nel resto dell'app (index.html).
private let navyDeep = Color(red: 0x0A / 255, green: 0x1F / 255, blue: 0x30 / 255)
private let brass = Color(red: 0xC9 / 255, green: 0xA2 / 255, blue: 0x27 / 255)
private let teal = Color(red: 0x4F / 255, green: 0xA8 / 255, blue: 0x9E / 255)
private let inkDim = Color(red: 0x8C / 255, green: 0xA3 / 255, blue: 0xB5 / 255)

private func formattedElapsed(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

@available(iOS 16.1, *)
struct TripActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // Vista lock screen / banner.
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "sailboat.fill")
                    .font(.title2)
                    .foregroundStyle(brass)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uscita in corso")
                        .font(.caption)
                        .foregroundStyle(inkDim)
                    Text(formattedElapsed(context.state.elapsedSeconds))
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    statLine(String(format: "%.1f kn", context.state.speedKn))
                    statLine(String(format: "%.1f nm", context.state.distanceNm))
                    statLine(String(format: "%.1f L", context.state.fuelLiters))
                }
            }
            .padding(16)
            .activityBackgroundTint(navyDeep)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("Velocità").font(.caption2).foregroundStyle(inkDim)
                        Text(String(format: "%.1f kn", context.state.speedKn)).font(.headline.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Durata").font(.caption2).foregroundStyle(inkDim)
                        Text(formattedElapsed(context.state.elapsedSeconds)).font(.headline.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(String(format: "%.1f nm", context.state.distanceNm), systemImage: "location.fill")
                        Spacer()
                        Label(String(format: "%.1f L", context.state.fuelLiters), systemImage: "fuelpump.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(inkDim)
                }
            } compactLeading: {
                Image(systemName: "sailboat.fill").foregroundStyle(brass)
            } compactTrailing: {
                Text(String(format: "%.0f kn", context.state.speedKn)).monospacedDigit()
            } minimal: {
                Image(systemName: "sailboat.fill").foregroundStyle(brass)
            }
            .keylineTint(teal)
        }
    }

    private func statLine(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.white)
    }
}
