# Oltre lo zip: evoluzione della configurazione aereo

Documento di analisi e proposta. Non descrive il comportamento attuale del codice come obiettivo,
ma come punto di partenza: la domanda è come arrivare a una configurazione che un gruppo di piloti
possa gestire da solo, restando dentro Google Drive / Sheets / Apps Script (e, al massimo, GCP).

---

## 1. Come funziona oggi

Il percorso completo, dal campo di testo al modello in memoria:

1. `SetAircraftDataScreen` chiede **URL** e **password** (`lib/screens/aircraft_select/aircraft_data_screen.dart`).
2. `downloadAircraftData()` scarica lo zip via HTTP(S), con Basic auth opzionale
   (`lib/helpers/aircraft_data.dart:395`).
3. `AircraftDataReader.validate()` decodifica lo zip in memoria, valida `aircraft.json` contro
   `assets/aircraft.schema.json` e verifica che ci siano `aircraft.jpg` e **un avatar per ogni nome**
   in `pilot_names` (`aircraft_data.dart:103-165`).
4. `addAircraftDataFile()` riscrive lo zip **decifrato** in `<appSupport>/aircrafts/<id>.zip`, più un
   `<id>.url` con l'URL di provenienza (`aircraft_data.dart:266-319`).
5. `open()` estrae tutto in `<tmp>/current_aircraft`; `toAircraftData()` costruisce il modello;
   `AppConfig` espone il resto all'app, comprese le immagini come `FileImage`
   (`lib/helpers/config.dart:162-171`).

Contenuto dell'archivio: `aircraft.json`, `aircraft.jpg`, `avatar-<nome minuscolo>.jpg`.

Il punto centrale è che **un unico file trasporta quattro cose con cicli di vita completamente diversi**:

| Contenuto | Cambia | Chi dovrebbe poterlo cambiare | Riservatezza |
|---|---|---|---|
| Anagrafica aereo (`callsign`, `location`, `timezone`, `hourmeter_multiplier`, feature flag, `documents_archive`) | raramente | l'amministratore del gruppo | nessuna |
| Roster (`pilot_names`, `no_pilot_name`, ruoli, foto) | spesso | ogni pilota, per sé; l'admin per il resto | nessuna |
| Coordinate del backend (`script_url`, `*_spreadsheet_id`, `google_calendar_id`, nomi dei fogli) | una volta | l'amministratore | bassa (sono id, non segreti) |
| Credenziali (`google_api_service_account`, `google_api_key`, `script_token`) | a ogni rotazione o revoca, **per pilota** | chi le emette | **massima** |

Tutto quello che segue nasce da questa fusione.

---

## 2. Dove si irrigidisce

**P1 — Un archivio per pilota.** `script_token` identifica il pilota e sta dentro `aircraft.json`,
quindi servono N archivi per N piloti (`docs/backend.md`, sezione "Aircraft data file"). E poiché
`admin` è un booleano dello stesso file, un admin ha bisogno di un archivio **diverso** dagli altri:
di fatto due varianti per aereo, più una per pilota.

**P2 — Le foto sono dentro l'archivio e sono obbligatorie.** `validate()` (`aircraft_data.dart:150-158`)
e `open()` (`:215-224`) **rifiutano l'intera configurazione** se manca l'avatar di un solo nome presente
in `pilot_names`. Conseguenze:

* un pilota non può cambiare la propria foto senza un nuovo zip prodotto da qualcun altro;
* aggiungere un pilota significa rigenerare e ridistribuire **tutti** gli archivi, perché
  `pilot_names` cresce e gli archivi vecchi non hanno il nuovo avatar: al primo refresh
  falliscono la validazione;
* il nome è la chiave del file (`avatar-${name.toLowerCase()}.jpg`), quindi rinominare un pilota
  — anche solo "Anna" → "Anna R." — orfana il file e rompe la configurazione.

**P3 — Ogni modifica costa un giro completo su tutti i dispositivi.** Il refresh
(`lib/screens/about/about_screen.dart:40`) richiede di ridigitare la password dello zip, che nessuno
ricorda, e riscarica l'intero archivio anche per un byte cambiato. Non c'è ETag né confronto di
versione, nonostante il meccanismo di hash esista già nel foglio Metadata.

**P4 — Segreti a vita lunga in un file destinato a un URL pubblico.** L'archivio contiene la chiave
privata di un service account con scope `calendar` + `spreadsheets`
(`lib/helpers/googleapis.dart:10-14`). Sul dispositivo finisce **in chiaro**: `decryptDataFile()`
salva lo zip senza password (`aircraft_data.dart:293`). Ne segue che:

* la revoca non funziona. Cancellare `token.<nome>` dal foglio blocca le scritture del flight log,
  ma chi ha avuto l'archivio una volta conserva una chiave che legge e scrive calendario e foglio
  direttamente, per sempre — fino a quando non si ruota la chiave e si ridistribuisce tutto a tutti;
* la rotazione della chiave è un evento che coinvolge ogni pilota;
* lo zip è un artefatto sensibile, e per questo deve nascerlo un tecnico.

**P5 — L'autorizzazione delle prenotazioni è solo lato client.** `admin` viene letto dal json
(`config.dart:65`) e usato per decidere chi può modificare le prenotazioni altrui
(`book_flight_modal.dart:393,443,536`), ma gli eventi sono scritti **direttamente** su Calendar con
il service account (`lib/services/book_flight_services.dart`). Chi modifica il proprio `aircraft.json`
diventa admin del calendario. Il flight log invece è protetto sul serio, perché passa dallo script,
che verifica `role.<nome>` nel foglio (`server/src/60_actions.js`). Le due metà dell'app hanno due
modelli di sicurezza diversi.

**P6 — Il foglio Metadata contiene i token in chiaro**, e la checklist di `docs/backend.md` chiede di
dare **accesso in scrittura al foglio a tutti i piloti**, in contraddizione con l'avvertenza della
sezione "Pilot tokens" ("give read access only to people you would hand every pilot's token to").
Nella configurazione documentata, quindi, ogni pilota può impersonare ogni altro pilota.

**P7 — Configurazione duplicata.** I nomi dei fogli e `no_pilot_name` vivono sia in `aircraft.json`
sia nelle Script Properties del deployment (`METADATA_SHEET_NAME`, `FLIGHT_LOG_SHEET_NAME`,
`NO_PILOT_NAME`). Nessuno dei due lati verifica l'altro: divergono in silenzio.

**P8 — Una credenziale richiesta e mai usata.** `google_api_key` è nella checklist, è nello schema, è
esposta da `AppConfig.googleApiKey` (`config.dart:74`) — e non viene letta da nessuna parte del codice.
È un passo di setup che non serve a niente.

**P9 — Il formato è ostile da produrre a mano.** JSON5 con commenti da rimuovere, la chiave del service
account da incollare come stringa JSON-escaped dentro un'altra stringa JSON, nomi file da far combaciare
in minuscolo con i nomi dei piloti. Il tool web in beta esiste proprio per questo, ed è la prova del
problema, non la soluzione.

**P10 — La distribuzione richiede infrastruttura.** "Servi lo zip da un URL HTTPS pubblico, eventualmente
con Basic auth": un gruppo di cinque piloti non ha un web server, e non deve averne uno.

**P11 — Monolite in memoria.** I due `FIXME` a `aircraft_data.dart:104` e `:179` sono sintomi: tutto
viene decodificato in RAM, tutto viene riscritto a ogni aggiornamento, non c'è granularità.

---

## 3. Principi della proposta

1. **Il config non deve contenere segreti.** È la leva che sblocca tutto il resto: se il config è
   pubblico, non serve più lo zip cifrato, non serve la password, non serve l'hosting privato, e lo
   stesso file vale per tutti i piloti.
2. **Ogni dato dove vive naturalmente.** Il roster in un foglio, le foto in una cartella Drive,
   l'anagrafica in un foglio, l'identità sul dispositivo. Tutti posti che l'utente sa già usare.
3. **Una sola porta per le scritture**: lo script. È la direzione già presa con il backend Apps Script
   (`3af1250`, `98a1f76`) — va completata, non invertita.
4. **Chi possiede il dato lo modifica**, dall'app o direttamente da Google.
5. **Nessun flag day.** Lo zip resta leggibile: le installazioni esistenti continuano a funzionare e
   migrano quando vogliono.

---

## 4. Le alternative

Sei mosse indipendenti. Ognuna ha valore da sola, e insieme compongono il percorso della sezione 5.

### A — Il config diventa un file su Drive (elimina l'hosting)

**Cosa cambia:** nessun web server. Il config sta in un file su Drive condiviso "chiunque abbia il
link", e l'app lo scarica con l'URL documentato dell'API Drive:

```
https://www.googleapis.com/drive/v3/files/<fileId>?alt=media&key=<apiKey>
```

che per un file link-shared funziona con la sola API key — finalmente un uso per `google_api_key` (P8).

**Lato app:** `AircraftDataReader` ha già il `TODO` "should be split into interface + 2 implementations"
(`aircraft_data.dart:73`): è esattamente il punto di innesto. Nasce una seconda implementazione che
legge un JSON invece di uno zip; la validazione con `aircraft.schema.json` resta identica.

**Pro:** l'admin modifica il config aprendo un file su Drive, in place, senza ricaricare nulla altrove;
l'URL non cambia mai.
**Contro:** da solo non risolve né i segreti né le foto né gli archivi per pilota. È solo il trasporto.
**Sforzo:** piccolo.

### B — Foto e roster fuori dal config

**Lato Google:** un foglio `Pilots` nella stessa spreadsheet (oppure righe dedicate in `Metadata`):

| id | display_name | role | avatar_file_id | active |
|---|---|---|---|---|
| `anna` | Anna Rossi | admin | `1AbC…` | sì |

Il campo chiave è `id`, stabile e disaccoppiato dal nome visualizzato: risolve il rinominare di P2.
Le immagini stanno in una cartella Drive creata **dallo script stesso** (dettaglio importante: una
cartella creata dallo script ricade nello scope `drive.file`, quindi non serve concedere accesso
all'intero Drive dell'utente).

**Lato script:** una nuova azione non mutante `config/get`, che restituisce anagrafica + roster +
riferimenti alle foto, con un `hash` complessivo. Il meccanismo esiste già: `flight_log.hash` viene
incrementato a ogni scrittura (`server/src/40_store.js`), basta aggiungere `roster.hash` e `config.hash`.

**Lato app:** l'app chiede `config/get` all'avvio; se l'hash non è cambiato non scarica niente. Le
immagini vanno in cache su disco per `avatar_file_id`, non per nome, e vengono invalidate solo quando
cambia quel campo. L'app continua a partire offline dalla cache — requisito da non perdere, oggi
garantito dallo zip locale.

**Come arrivano i byte delle foto.** Tre opzioni, in ordine di preferenza:

1. cartella Drive link-shared + `files.get?alt=media&key=<apiKey>` come in A: documentato, cacheabile,
   nessuna credenziale nuova. Le foto diventano leggibili da chi ha il link: sensibilità bassa, ma va detto;
2. base64 dentro la risposta dello script: nessuna esposizione pubblica, ma `ContentService` non può
   restituire `image/jpeg` (non esiste nel suo enum di MIME type), quindi si paga l'encoding e le
   risposte vanno tenute piccole — con avatar a 256 px sono decine di KB, accettabile;
3. `https://drive.google.com/thumbnail?id=<id>&sz=w256`: comodo e già ridimensionato, ma è un endpoint
   non documentato. Utile come ottimizzazione, non come unico meccanismo.

**Self-service sulla foto**, due strade che convivono:

* il pilota (o l'admin) sostituisce il file nella cartella Drive condivisa: zero codice, funziona subito;
* dall'app: azione `roster/set-avatar` che carica l'immagine, lo script la scrive su Drive con `DriveApp`
  e aggiorna `avatar_file_id`. Un pilota può modificare solo la propria riga, un admin tutte.

**Pro:** cade P2 per intero — foto modificabili, piloti aggiungibili e rinominabili senza toccare
nessuna installazione. Cade anche il grosso di P3.
**Contro:** `validate()` non può più pretendere le foto; serve un placeholder per l'avatar mancante
(esiste già il precedente di `assets/images/nopilot_avatar.png`). Lo script guadagna lo scope Drive.
**Sforzo:** medio.

### C — Enrollment: un config per aereo, un token per dispositivo

**Obiettivo:** far sparire il "per pilota" dal config (P1).

**Flusso:** l'admin genera un codice di invito monouso (riga `invite.<codice>` nel foglio, con scadenza,
generabile dall'app o da un menù nello spreadsheet). Il pilota installa il config **comune**, scegli il
proprio nome, digita il codice; una nuova azione `auth/redeem` verifica il codice, genera un token
casuale, scrive nel foglio il suo **hash SHA-256** (`Utilities.computeDigest`) e restituisce il token in
chiaro una volta sola. L'app lo conserva in `flutter_secure_storage` (Keychain / Keystore), non in un
file nella cartella di supporto.

**Chiavi nel foglio:** `token.<pilotId>.<deviceLabel>` invece di `token.<nome>`, così revocare un
telefono non disconnette il tablet. `authenticate()` (`server/src/20_auth.js`) già scorre tutte le
chiavi con prefisso `token.`: cambia solo come estrae il pilota dalla chiave e il confronto, che diventa
tra hash.

**Effetti collaterali positivi:**

* il foglio non contiene più credenziali riutilizzabili → la contraddizione P6 si scioglie: si può dare
  accesso al foglio ai piloti senza regalare l'identità di tutti;
* il `role` arriva dal server insieme al token, quindi `admin` esce dal config (P1, seconda metà) e
  smette di essere autodichiarato;
* la revoca diventa un'operazione reale e per dispositivo.

**Pro:** un solo config per aereo, onboarding autonomo del pilota, revoca vera.
**Contro:** una schermata nuova nell'app (codice di invito) e la gestione del ciclo di vita del token
(scadenza, rinnovo, token non più valido → riavvio dell'enrollment).
**Sforzo:** medio.

### D — Lo script come unica porta, e la fine del service account nel client

È il passo che elimina P4 e P5. Si fa in due tempi, e il primo è sorprendentemente economico.

**D1 — Scritture tutte dallo script, service account in sola lettura.**
Si aggiungono `booking/insert|update|delete` allo script, implementate con `CalendarApp`: il calendario
viene scritto dall'identità del proprietario dello script, e l'autorizzazione (chi può toccare la
prenotazione di chi) si valuta lato server con lo stesso schema già usato per il flight log in
`60_actions.js`. Nel config resta un service account **secondo**, con permesso di sola lettura su
calendario e foglio, per le letture dirette. Un config che perde vale molto meno: nessuno può scrivere,
nessuno può cancellare.

Da notare: l'evento risulterà creato dal proprietario dello script e non dal pilota, ma il nome del
pilota è già il titolo dell'evento, quindi nulla si perde.

**D2 — Niente credenziali Google nel config.**
Si aggiungono le letture allo script (`flight-log/list`, `booking/list`, `activities/list`) e si
rimuovono `google_api_service_account` e `google_api_key`. A quel punto il config contiene **solo id e
URL**: può essere pubblico, e diventa un QR code o un link. Il prezzo va detto con chiarezza:

* **latenza**: una chiamata Apps Script costa tipicamente 1-2 s contro i ~300 ms di una lettura diretta
  di Sheets, e c'è il doppio giro del redirect già documentato in `server/openapi.yaml`;
* **quota**: il tempo di esecuzione degli script è contingentato (dell'ordine di 90 minuti al giorno per
  gli account consumer, 6 ore per Workspace). Scorrere la vista mensile del calendario generando una
  chiamata per scroll consuma quota in fretta. Servono cache lato script (`CacheService`), paginazione e
  invalidazione basata sull'hash — ossia esattamente la strada già imboccata con `*.hash`.

Per questo D2 dà il meglio se accoppiato a E, che restituisce all'app un modo legittimo per leggere
direttamente.

**Pro:** un solo modello di sicurezza per tutta l'app, revoca reale, config non segreto.
**Contro:** è il pezzo di lavoro più grosso, e sposta il carico di lettura su Apps Script.
**Sforzo:** grande (D1 medio, D2 grande).

### E — Google Sign-In come identità

Il pilota si autentica con il **proprio** account Google. L'app ottiene un ID token e lo manda allo
script, che lo verifica (`UrlFetchApp` su `https://oauth2.googleapis.com/tokeninfo?id_token=…`,
controllando `aud` e `exp`) e cerca l'email in una riga `pilot.<email>` del foglio: da lì nome e ruolo.

Il dettaglio che rende questa strada praticabile: servono **solo gli scope `openid email profile`**, che
non sono sensibili e **non richiedono il processo di verifica di Google**, al contrario di `calendar` e
`spreadsheets`. L'identità non costa una revisione annuale.

**Pro:** zero segreti sul dispositivo, nessun token da gestire, nessun codice di invito; l'admin invita
un'email; l'accesso multi-aereo diventa naturale (una identità, N aerei); la revoca è rimuovere una riga.
**Contro:** un OAuth client per piattaforma da configurare **una volta** in fase di build dell'app
(SHA-1 Android, bundle id iOS, desktop) — non è più un artefatto per aereo prodotto da un tecnico, ed è
questa la differenza che conta. Su Linux/Windows il flusso di sign-in è meno liscio che su mobile.

**Variante ambiziosa:** se i piloti hanno già permesso di scrittura su calendario e foglio — e la
checklist attuale dice di darglielo — l'app potrebbe usare il token OAuth **del pilota** per leggere (e
perfino scrivere) direttamente, facendo sparire il service account e ottenendo gratis la cronologia
revisioni per autore. Ma `calendar` e `spreadsheets` sono scope sensibili: consenso da verificare, con
tetto di 100 utenti in modalità testing. Va valutato, non dato per scontato.

**Sforzo:** medio per la sola identità, grande per la variante.

### F — Setup self-service: template, wizard, QR code

Le mosse precedenti rendono la configurazione modificabile dall'utente. Questa rende creabile dall'utente
anche il primo impianto, che oggi è la parte più tecnica (`docs/backend.md`: 8 voci di checklist GCP,
`clasp login`, `clasp push`, script properties, deployment).

* **Lo script torna dentro il template.** Uno script *bound* viene copiato insieme allo spreadsheet: chi
  clicca il link `/copy` si porta via anche il codice. Restano da fare all'utente un'autorizzazione e un
  singolo Deploy → New deployment, perché i deployment non vengono copiati. Il git resta la sorgente di
  verità: `deploy.sh` può, in più, aggiornare lo script del template a ogni release.
* **Un menù `onOpen` "Airborne → Setup"** nello spreadsheet, che fa da wizard: scrive le script properties
  da sé, crea il calendario con `CalendarApp`, crea la cartella Drive degli avatar, genera i codici di
  invito, valida la configurazione e mostra il **QR code** dell'aereo da mandare ai piloti su WhatsApp.
* **Il "config" percepito dall'utente diventa una stringa**: l'URL del deployment (o il suo id). Tutto il
  resto lo scopre l'app con `config/get`.

Il service account (e quindi mezza checklist GCP, comprese API key e progetto Cloud) sparisce se si
arriva a D2 o a E. È probabilmente la semplificazione più visibile per l'utente finale.

**Sforzo:** medio, e quasi tutto in Apps Script, non nell'app.

### G — Quello che sconsiglio, e il poco di GCP che vale la pena

* **Firestore / Cloud Run / Firebase Auth**: risolverebbero tutto, ma portano fatturazione, un servizio
  da tenere in piedi, e soprattutto **portano via i dati da Sheets e Calendar**, che oggi sono una
  feature: il gruppo apre il foglio e vede i voli, condivide il calendario col telefono. Non vale il
  cambio, e non è il perimetro chiesto.
* **Secret Manager**: inutile se il client non ha più segreti (D2/E). Sarebbe solo un posto in più dove
  tenere la chiave che stiamo cercando di eliminare.
* **Cloud Storage per le foto**: tecnicamente più pulito di Drive (URL stabili, cache header), ma
  richiede un progetto con billing e un bucket da amministrare. Drive è già in mano all'utente: preferibile.
* **Un solo pezzo di GCP resta sensato**, ed è quello che c'è già: il progetto Cloud che ospita il
  consent screen dell'OAuth client per Google Sign-In (E). È un artefatto **dell'app**, uno per tutti,
  non uno per aereo.

---

## 5. Percorso consigliato

Cinque passi, ognuno rilasciabile da solo, ognuno retrocompatibile con gli zip esistenti.

| # | Passo | Cosa risolve | Sforzo |
|---|---|---|---|
| 1 | Split di `AircraftDataReader` (il `TODO` già scritto) + sorgente "JSON su Drive" accanto allo zip; schema condiviso | P9, P10, P11 | S |
| 2 | Foglio `Pilots` + cartella avatar su Drive + azione `config/get` con hash; cache locale per id; placeholder avatar | P2, P3, P7 | M |
| 3 | Enrollment con codice di invito, token per dispositivo con hash nel foglio, `role` dal server, secure storage | P1, P6, e il lato client di P5 | M |
| 4 | `booking/*` sullo script + service account declassato a sola lettura | P5, gran parte di P4 | M |
| 5 | Letture sullo script **oppure** Google Sign-In; via le credenziali dal config; QR code e wizard `onOpen` | P4 per intero, P8 | L |

Dopo il passo 3 il "config" è **uno per aereo**; dopo il passo 5 non contiene segreti e diventa una
stringa da condividere in chat.

**Compatibilità.** Lo schema prende un campo `config_version`. L'app riconosce tre sorgenti: zip legacy,
JSON remoto, e URL/QR di deployment; le installazioni con zip continuano a funzionare e al primo
`config/get` disponibile si migrano da sole, riusando l'`<id>.url` già salvato. Nessuna delle azioni
nuove è mutante nel senso del protocollo tranne quelle di scrittura, quindi `KNOWN_ACTIONS` e
`MUTATING_ACTIONS` (`server/src/10_protocol.js`) crescono senza rompere il contratto v1; se cambiano le
semantiche, `PROTOCOL_V_MAX` passa a 2 e il client vecchio riceve `PROTOCOL_INCOMPATIBLE`, che già sa
gestire.

---

## 6. Prima e dopo: cosa può fare l'utente da solo

| Operazione | Oggi | Dopo il passo 3 | Dopo il passo 5 |
|---|---|---|---|
| Cambiare la propria foto | nuovo zip da un tecnico, per tutti | dall'app, o sostituendo un file su Drive | idem |
| Aggiungere un pilota | riga nel foglio + N zip rigenerati | riga + un codice di invito | invito per email |
| Rinominare un pilota | rompe gli avatar | rinomina il `display_name` | idem |
| Promuovere un admin | zip dedicato con `admin: true` | si cambia `role` nel foglio | idem |
| Togliere un pilota | riga cancellata, ma conserva le chiavi | revoca reale, per dispositivo | rimozione dell'email |
| Cambiare orario/base/posizione | nuovo zip | si modifica il foglio | idem |
| Ruotare le credenziali | nuovo zip per tutti | solo il service account in lettura | non ci sono più credenziali |
| Primo setup dell'aereo | checklist GCP + `clasp` | idem | copia template + wizard + un Deploy |

---

## 7. Insidie da tenere presenti

* **Offline.** Oggi lo zip locale fa partire l'app senza rete. La cache di config, roster e avatar deve
  garantire la stessa cosa, con invalidazione per hash e nessun blocco se `config/get` non risponde.
* **Quote e latenza di Apps Script** (vedi D2): tempo di esecuzione contingentato per account, risposte
  da tenere piccole, `CacheService` e paginazione non opzionali se le letture passano dallo script.
* **`ContentService` non serve binario**: gli avatar dallo script sono base64, oppure si passa da Drive.
* **`drive.file` basta** se la cartella la crea lo script; qualunque cartella scelta a mano dall'utente
  richiederebbe uno scope più largo. Conviene farla creare allo script.
* **Verifica OAuth**: `openid email profile` non la richiede, `calendar` e `spreadsheets` sì. È la
  ragione per cui E conviene tenerla all'identità e lasciare i dati dietro lo script.
* **Il token nel secure storage** va trattato come credenziale: niente log, niente backup in chiaro,
  gestione esplicita del "token revocato" con ritorno all'enrollment.
* **Un deployment per aereo resta necessario** (lo script è `spreadsheets.currentonly` e bound), quindi
  il wizard di F va scritto pensando che chi lo usa non ha mai visto l'editor Apps Script.
* **Test.** `test/fixtures/aircraft.dart` costruisce lo zip a mano e `test/helpers/aircraft_data_test.dart`
  ne verifica le regole: le fixture vanno estese alla nuova sorgente, non sostituite, se si vuole
  continuare a coprire il percorso legacy.

---

## 8. Decisioni da prendere prima di scrivere codice

1. **Identità: token di enrollment (C) o Google Sign-In (E)?** C si scrive tutto in casa e funziona
   uguale su ogni piattaforma; E elimina i segreti ma vincola a un OAuth client per piattaforma e a un
   flusso desktop meno liscio. Sono compatibili: C ora, E dopo, con lo stesso `role` nel foglio.
2. **Le letture passano dallo script (D2) o restano dirette con un service account di sola lettura (D1)?**
   È il compromesso tra "zero credenziali nel config" e "latenza e quota". D1 si può fare subito, D2 si
   può decidere dopo aver misurato.
3. **Gli avatar sono pubblici-per-link su Drive o base64 dallo script?** Semplicità contro riservatezza,
   su un dato di sensibilità bassa ma non nulla.
4. **Lo script torna nel template?** È ciò che rende il setup autonomo, e va conciliato con il git come
   sorgente di verità (`deploy.sh` che aggiorna anche il template a ogni release).
5. **Quanto a lungo si sostiene lo zip legacy?** Proposta: finché è a costo zero, cioè finché la
   sorgente zip resta una delle implementazioni dietro l'interfaccia del passo 1.
