# Giornale di Bordo — app iOS (Capacitor), solo gommone

Questa cartella impacchetta in un progetto Capacitor **una versione dedicata e separata**
dell'app, incentrata solo sul gommone: `ios-app/www/index.html` è un file a sé stante,
copiato una volta dalla radice del repo e poi editato per togliere la schermata di scelta
veicolo (auto/scooter/gommone) e avviarsi direttamente nell'app barca — **non è più
collegato o sincronizzato automaticamente con `../index.html`**, che resta intatto e
continua a servire il sito con tutti e tre i veicoli. Se in futuro modifichi qualcosa nel
sito che vuoi anche nell'app iOS (o viceversa), va riportato a mano nell'altro file: sono
due file indipendenti da qui in avanti.

Il codice di auto/scooter (markup, funzioni `va*`, ecc.) è ancora fisicamente presente in
`ios-app/www/index.html` — non l'ho rimosso riga per riga, perché tagliare migliaia di righe
di codice interconnesso senza poterlo compilare/testare avrebbe un rischio di rottura ben
più alto del beneficio. È semplicemente **irraggiungibile**: la schermata di scelta veicolo
non c'è più, l'app va dritta al gommone e non esiste alcun pulsante o link per uscirne. Se
vuoi anche la pulizia fisica del codice inutilizzato, è un lavoro a parte che possiamo fare.

Oltre a questo, ci sono due funzionalità native aggiunte rispetto alla versione web:

1. **Notifiche push per le scadenze** (assicurazione, bollo, revisione) — plugin ufficiale
   `@capacitor/push-notifications` + un backend Firebase Cloud Functions in `../functions/`.
2. **Live Activity** durante un'uscita in corso (lock screen / Dynamic Island) — plugin
   nativo scritto per l'occasione (`LiveActivityPlugin.swift`), perché non esiste nessuna
   libreria "pronta" per questo: è un'API Apple (ActivityKit) accessibile solo da codice
   Swift nativo, impossibile da implementare in JavaScript puro.

**Importante — cosa NON ho potuto verificare**: lavoro da un ambiente Linux, senza Xcode né
un Mac. Ho scritto tutto il codice Swift seguendo i pattern documentati da Apple/Capacitor e
ho controllato la sintassi di tutto il resto (JS, JSON, plist), ma **il codice Swift non è
mai stato compilato**. È molto probabile che serva qualche aggiustamento in Xcode alla prima
build (build error banali, nomi, ecc.) — nessuna di queste due funzionalità va considerata
"finita e pronta" finché qualcuno con un Mac non l'ha effettivamente compilata e provata su
un dispositivo reale.

## Cosa è già pronto

- Progetto Capacitor con piattaforma iOS generata (`ios/App/App.xcodeproj`).
- `@capacitor/push-notifications` installato e collegato.
- `www/index.html`: file separato, parte dal contenuto del sito ma senza launcher/scelta
  veicolo — si avvia direttamente sul gommone. Registrazione push feature-detected (no-op se
  aperto in un browser normale), chiamate alla Live Activity all'inizio/durante/fine di
  un'uscita GPS.
- `AppDelegate.swift` aggiornato con i callback APNs richiesti dal plugin push.
- `Info.plist`: aggiunte le chiavi per il permesso di localizzazione e per abilitare le
  Live Activity (`NSSupportsLiveActivities`).
- `App.entitlements` pre-compilato con `aps-environment` (va comunque collegato al target
  da Xcode, vedi sotto).
- `LiveActivityPlugin.swift` + `TripActivityAttributes.swift` (nel target App) e
  `TripActivityWidgetBundle.swift` + `TripActivityWidgetLiveActivity.swift` (pensati per un
  nuovo target Widget Extension da creare in Xcode, vedi sotto).
- Backend `../functions/index.js`: una Cloud Function schedulata (una volta al giorno) che
  controlla assicurazione/bollo/revisione di gommone e carrello e manda una notifica push a
  chi ha un dispositivo registrato (niente auto/scooter: l'app iOS non li usa più).
  **Non copre ancora** le scadenze di manutenzione motore (dipendono anche dalle ore di
  navigazione, logica più complessa) né le dotazioni di sicurezza — se le vuoi, va esteso.

## Passaggi che restano da fare (servono un Mac + Xcode)

### 1. Bundle ID e firma
Il bundle ID placeholder è `com.giornaledibordo.app` (in `capacitor.config.json` e nel
progetto Xcode). Cambialo con uno che possiedi tu (di solito legato al tuo Apple Developer
Team, es. `com.tuonome.giornalebordo`), sia in `capacitor.config.json` che nelle impostazioni
del target App in Xcode ("Signing & Capabilities").

### 2. Aprire il progetto e sincronizzare
```
cd ios-app
npm install       # se non già fatto
npm run sync      # npx cap sync ios (rilegge www/index.html così com'è)
npm run open      # apre Xcode
```
Da rilanciare (`npm run sync`) ogni volta che modifichi `ios-app/www/index.html` — che è il
file da editare per qualsiasi modifica specifica dell'app iOS (non `../index.html`, che è il
sito e non ha più nulla a che fare con questa cartella).

### 3. Abilitare Push Notifications (Xcode)
Target **App** → tab "Signing & Capabilities" → "+ Capability" → **Push Notifications**.
Xcode collega da solo l'entitlement e aggiorna Info.plist. Se preferisci usare il file che ho
già preparato (`App/App.entitlements`), assegnalo tu a mano in Build Settings →
`CODE_SIGN_ENTITLEMENTS`.

### 4. Creare il target Widget Extension per la Live Activity
1. File → New → Target… → **Widget Extension**.
2. Nome: `TripActivityWidget`. Spunta **"Include Live Activity"**.
3. Xcode crea dei file di esempio nel nuovo target: **cancellali** e sostituiscili aggiungendo
   (drag & drop, o "Add Files to App…") i file già pronti in
   `ios/App/TripActivityWidget/TripActivityWidgetBundle.swift` e
   `TripActivityWidgetLiveActivity.swift`, assicurandoti che il "Target Membership" (pannello
   a destra) sia impostato sul nuovo target `TripActivityWidget`, non su `App`.
4. **Fondamentale**: seleziona `App/App/TripActivityAttributes.swift` e nel "Target
   Membership" spunta **entrambi** i target, App e TripActivityWidget — la app (il plugin) e
   la widget extension (la UI) devono vedere la stessa identica definizione di
   `TripActivityAttributes`, altrimenti non compila.
5. Sul target `TripActivityWidget`, tab "Signing & Capabilities", verifica che il minimo iOS
   deployment target sia **16.1** o superiore (le Live Activity non esistono prima).
6. Verifica anche il deployment target del target `App`: se lo abbassi sotto 16.1 va bene lo
   stesso (il plugin usa `@available(iOS 16.1, *)` e su versioni precedenti resta inerte),
   ma la Live Activity semplicemente non comparirà su iPhone con iOS più vecchio.

### 5. Collegare APNs a Firebase (per le notifiche scadenze)
1. Apple Developer portal → Certificates, Identifiers & Profiles → Keys → crea una **APNs
   Auth Key** (consigliata, invece del certificato classico — non scade).
2. Firebase Console → Project Settings → Cloud Messaging → carica quella chiave APNs (serve
   Key ID + Team ID, entrambi visibili nel portal Apple Developer).
3. Non serve altro codice: `firebase-admin` nella Cloud Function usa già Firebase Cloud
   Messaging, che instrada automaticamente su APNs una volta collegata la chiave.

### 6. Deploy del backend (Cloud Function)
```
cd ..                        # torna alla radice del repo
firebase login                # se non già fatto
firebase use --add            # collega il TUO progetto Firebase (quello già usato dall'app)
cd functions && npm install
cd .. && firebase deploy --only functions
```
Da qui in poi la funzione `sendDeadlineReminders` gira da sola ogni giorno alle 8:00
(Europe/Rome) — non serve toccarla di nuovo a meno di aggiungere nuovi tipi di scadenza.

### 7. Icone, splash screen, App Store Connect
- Icone app: sostituisci gli asset in `ios/App/App/Assets.xcassets/AppIcon.appiconset/`
  (Xcode ha un editor visuale per questo).
- Crea l'app su [App Store Connect](https://appstoreconnect.apple.com), stesso bundle ID.
- Servono screenshot, descrizione, categoria, privacy policy (obbligatoria: l'app raccoglie
  posizione GPS + dati account, va dichiarato nel questionario "App Privacy").
- **Linee guida Apple 4.2** (rifiuto per "sito web impacchettato"): con push notifications e
  Live Activity native questa app ha una giustificazione più solida di un semplice wrapper,
  ma vale la pena rivedere la guideline prima della submission.

## Limiti noti / cose da sapere

- **GPS in background**: oggi il tracciamento gira nel JS della WebView tramite
  `navigator.geolocation.watchPosition`, che **si mette in pausa quando l'app va in
  background** (schermo bloccato, altra app in primo piano). La Live Activity mostrata sulla
  lock screen quindi potrebbe smettere di aggiornarsi non appena si blocca lo schermo, anche
  se resta visibile con l'ultimo dato ricevuto. Per un tracciamento realmente continuo in
  background servirebbe spostare il GPS su un plugin nativo con
  `CLLocationManager.allowsBackgroundLocationUpdates` + background mode "Location updates" —
  non incluso in questa prima versione.
- Gli aggiornamenti della Live Activity sono locali (dal telefono stesso mentre l'app è
  attiva), non tramite push ActivityKit: più semplice da implementare, ma significa che se
  l'app viene proprio terminata dal sistema la Live Activity resta ferma sull'ultimo valore
  finché non la chiudi tu o scade da sola.
- Il backend delle notifiche copre assicurazione/bollo/revisione, non manutenzione motore né
  dotazioni di sicurezza.
- Bundle ID, Team di firma, e `.firebaserc` (progetto Firebase) sono placeholder/mancanti di
  proposito: vanno impostati con i tuoi dati reali, non ho le tue credenziali.
