import Foundation
import Capacitor
import ActivityKit

/// Plugin Capacitor nativo (nessun equivalente web: su iOS < 16.1 o quando l'utente ha
/// disattivato le Live Activity, isSupported() torna false e l'app JS non prova a usarlo).
///
/// Espone a JS (Capacitor.Plugins.LiveActivity): isSupported(), start(), update(), end().
/// Vedi la chiamata lato JS in index.html: startLiveActivity()/updateLiveActivity()/endLiveActivity().
@objc(LiveActivityPlugin)
public class LiveActivityPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "LiveActivityPlugin"
    public let jsName = "LiveActivity"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isSupported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "update", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "end", returnType: CAPPluginReturnPromise)
    ]

    // Any? invece di Activity<TripActivityAttributes>? perché quel tipo esiste solo da iOS 16.1
    // in poi: una proprietà tipizzata direttamente non potrebbe essere dichiarata su versioni
    // precedenti. L'accesso tipizzato passa dalla computed property sotto, disponibile solo
    // dove il compilatore sa già che siamo su iOS 16.1+.
    private var currentActivity: Any?

    @available(iOS 16.1, *)
    private var typedActivity: Activity<TripActivityAttributes>? {
        get { currentActivity as? Activity<TripActivityAttributes> }
        set { currentActivity = newValue }
    }

    @objc func isSupported(_ call: CAPPluginCall) {
        if #available(iOS 16.1, *) {
            call.resolve(["supported": ActivityAuthorizationInfo().areActivitiesEnabled])
        } else {
            call.resolve(["supported": false])
        }
    }

    @objc func start(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *) else {
            call.reject("Le Live Activity richiedono iOS 16.1 o successivo.")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            call.reject("L'utente ha disattivato le Live Activity per questa app.")
            return
        }
        // Se per qualche motivo ce n'era già una attiva (es. l'app è stata terminata a metà
        // uscita), la chiudiamo prima di aprirne una nuova invece di lasciarne due appese.
        if typedActivity != nil {
            let stale = typedActivity
            Task { await stale?.end(nil, dismissalPolicy: .immediate) }
            typedActivity = nil
        }

        let attributes = TripActivityAttributes(startedAt: Date())
        let state = TripActivityAttributes.ContentState(
            speedKn: call.getDouble("speedKn") ?? 0,
            distanceNm: call.getDouble("distanceNm") ?? 0,
            elapsedSeconds: call.getInt("elapsedSeconds") ?? 0,
            fuelLiters: call.getDouble("fuelLiters") ?? 0
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            self.typedActivity = activity
            call.resolve(["id": activity.id])
        } catch {
            call.reject("Impossibile avviare la Live Activity: \(error.localizedDescription)")
        }
    }

    @objc func update(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *), let activity = typedActivity else {
            call.resolve()
            return
        }
        let state = TripActivityAttributes.ContentState(
            speedKn: call.getDouble("speedKn") ?? 0,
            distanceNm: call.getDouble("distanceNm") ?? 0,
            elapsedSeconds: call.getInt("elapsedSeconds") ?? 0,
            fuelLiters: call.getDouble("fuelLiters") ?? 0
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        call.resolve()
    }

    @objc func end(_ call: CAPPluginCall) {
        guard #available(iOS 16.1, *), let activity = typedActivity else {
            call.resolve()
            return
        }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        typedActivity = nil
        call.resolve()
    }
}
