# Design: Nuovo Flusso Prenotazione + Fix Profilo
**Data:** 2026-06-08  
**Stato:** Approvato

---

## Obiettivo

Combinare due modifiche in un unico build Flutter:

1. **Fix profilo:** il salvataggio del numero di telefono fallisce per utenti Gmail/Apple con cognome vuoto a causa di un validatore bloccante nella vecchia versione dell'app. Il fix è già nel codice (validatore cognome rimosso, policy RLS Supabase aggiunte). Nessuna modifica aggiuntiva necessaria — serve solo il deploy.

2. **Nuovo flusso prenotazione:** invertire l'ordine di selezione stylist e data/ora. L'utente sceglie prima lo stylist, poi vede solo gli slot in cui QUELLO stylist specifico è disponibile.

---

## Flusso Attuale vs Nuovo

| Step | Attuale | Nuovo |
|------|---------|-------|
| 1 | BookingSelectionPage (uomo/donna) | BookingSelectionPage (uomo/donna) |
| 2 | ServiceSelectionPage | ServiceSelectionPage |
| 3 | DateTimeSelectionPage | **StylistSelectionPage (NUOVA)** |
| 4 | StylistSelectionPageFinal | **DateTimeSelectionPage (MODIFICATA)** |
| 5 | BookingConfirmationPage | BookingConfirmationPage |
| 6 | PaymentSelectionPage | PaymentSelectionPage |

---

## Modifiche ai File

### 1. `lib/service_selection_page.dart` — modifica minima

**Cosa cambia:** la navigazione finale, invece di andare a `DateTimeSelectionPage`, va alla nuova `StylistSelectionPage`.

**Parametri passati:** `section`, `selectedServices`, `totalDuration`, `totalPrice` (invariati).

---

### 2. `lib/stylist_selection_page.dart` — FILE NUOVO

**Scopo:** mostrare tutti gli stylist del sesso giusto, senza alcun filtro per data/ora.

**Parametri ricevuti:**
- `section` (String) — 'uomo' o 'donna'
- `selectedServices` (List<Map<String, dynamic>>)
- `totalDuration` (Duration)
- `totalPrice` (double)

**Logica:**
- Carica da Supabase tutti gli stylist con `sesso_id` corrispondente e `deleted_at IS NULL`
- Mostra lista di card con: nome stylist + testo fisso "Seleziona per vedere le disponibilità"
- Nessun calcolo di disponibilità — si mostrano tutti sempre
- Al tap su uno stylist → naviga a `DateTimeSelectionPage` passando anche `selectedStylist`

**UX se lista vuota:** messaggio "Nessuno stylist disponibile al momento".

---

### 3. `lib/datetime_selection_page.dart` — MODIFICATA

**Nuovi parametri ricevuti:**
- `selectedStylist` (Map<String, dynamic>) — lo stylist scelto nella schermata precedente

**Cambio 1 — `_checkAvailability`:**  
Invece di recuperare tutti gli stylist IDs del sesso via due query (`STYLIST_SESSO_TAGLIO` + `STYLIST`), usa direttamente `[selectedStylist['id'] as int]` come lista di un solo elemento. Questo riduce le query da 2 a 0 per questa parte.

**Cambio 2 — `_isSlotAvailableWithAbsences`:**  
La riga finale cambia da:
```dart
// Prima: slot libero se ALMENO UNO stylist è disponibile
int availableStylistCount = allStylistIds.length - unavailableStylistIds.length;
return availableStylistCount > 0;
```
a:
```dart
// Dopo: slot libero solo se QUESTO stylist specifico è disponibile
return !unavailableStylistIds.contains(selectedStylist['id'] as int);
```

**Cambio 3 — navigazione finale:**  
Invece di andare a `StylistSelectionPageFinal`, va direttamente a `BookingConfirmationPage` passando `selectedStylist`.

**Invariato:** tutta la logica di orari settimanali, eccezioni, assenze, generazione slot.

---

### 4. `lib/stylist_selection_page_final.dart` — INUTILIZZATA

Non viene più chiamata. Rimane nel progetto senza essere eliminata. Non causa warning o errori di compilazione poiché non è un entry point.

---

## Fix Profilo — Dettaglio

### Causa root
Gli utenti Gmail/Apple con un solo nome (senza cognome) avevano `cognome = ''` nel DB. Il vecchio form aveva il validatore cognome obbligatorio → il form non si inviava → il telefono non veniva salvato.

### Fix già implementato
- `lib/profile_page.dart`: validatore cognome rimosso (ritorna sempre `null`)
- Supabase: policy `users_insert_always` (INSERT WITH CHECK true) aggiunta
- Supabase: policy `users_update_own` (UPDATE USING true WITH CHECK true) aggiunta
- DB: 31 utenti con `telefono NULL` o `''` aggiornati a `'0000000000'`

### Nessuna modifica aggiuntiva necessaria
Il fix sarà attivo per tutti gli utenti non appena installano la nuova versione dell'app.

---

## Dati Supabase Coinvolti

| Tabella | Operazione | Note |
|---------|-----------|------|
| `STYLIST` | SELECT | Filtra per `deleted_at IS NULL` |
| `STYLIST_SESSO_TAGLIO` | SELECT | Join per filtrare per sesso |
| `APPUNTAMENTI` | SELECT | Per trovare slot occupati dello stylist scelto |
| `STYLIST_ASSENZE` | SELECT | Per trovare assenze dello stylist scelto |
| `orari_settimanali` | SELECT | Invariato |
| `orari_eccezioni` | SELECT | Invariato |
| `USERS` | UPDATE | Fix profilo — già funzionante |

---

## Build e Deploy

- **Versione:** 1.0.1+14 (già configurata)
- **Android:** generare nuovo AAB → caricare su Play Store
- **iOS:** Archive in Xcode → caricare su App Store Connect
- **Backend Railway:** nessuna modifica necessaria
- **Supabase:** nessuna migrazione necessaria (policy già aggiunte)

---

## Test Plan

1. **Fix profilo:**
   - Login con Gmail → aprire profilo → inserire numero di telefono → Salva → verificare che il numero sia salvato
   - Login con email/password → stessa verifica

2. **Nuovo flusso prenotazione:**
   - Sezione → Servizi → compare lista stylist → selezionare uno stylist → compare calendario → selezionare data e ora → conferma con lo stylist scelto
   - Verificare che gli slot mostrati siano solo quelli in cui quello stylist è libero (confrontare con admin panel)
   - Selezionare uno stylist con poche disponibilità → verificare che il calendario mostri meno slot rispetto a prima
