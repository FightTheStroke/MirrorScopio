import SwiftUI
import Charts

// MARK: - Dashboard dei progressi

/// La schermata che il bambino (e l'adulto) apre per capire come sta andando.
/// Regola progettuale: mostrare il percorso, mai il giudizio.
/// Ogni numero negativo è nascosto o ammorbidito; ogni traguardo è celebrato.
struct DashboardView: View {
    @ObservedObject var store: Store
    var onClose: () -> Void

    @Environment(\.palette) private var palette

    /// Quale riga delle sessioni recenti espone le parole da ripassare.
    @State private var sessioneEspansa: UUID?
    /// Mostra il dialogo di conferma prima di cancellare lo storico.
    @State private var mostraConfermaReset = false
    @State private var pagina: Pagina = .adesso

    private var a11y: A11ySettings { store.current.a11y }
    private var bambino: Learner { store.current }
    private var sessioni: [SessionRecord] { store.currentHistory }

    // Le ultime 20 sessioni in ordine cronologico: nei grafici il tempo
    // scorre da sinistra (passato) a destra (oggi), non al contrario.
    private var sessioniGrafico: [SessionRecord] {
        Array(sessioni.prefix(20).reversed())
    }

    // Punti dati precalcolati per evitare ricalcoli ripetuti nei due grafici.
    private var puntiGrafico: [_PuntoGrafico] {
        sessioniGrafico.enumerated().map { i, s in
            _PuntoGrafico(id: i + 1,
                          accuratezza: s.accuracy * 100,
                          sogliaMs: s.thresholdMs)
        }
    }

    /// Le pagine dei progressi, con lo stesso elenco a sinistra delle
    /// Impostazioni.
    ///
    /// Era una colonna sola lunghissima: livello, serie, numeri, due grafici,
    /// venti obiettivi e lo storico, tutto di fila. Per arrivare a una cosa
    /// bisognava attraversare tutte le altre, e chi fatica a tenere insieme
    /// molte informazioni si perdeva molto prima della fine — proprio nella
    /// schermata che dovrebbe far vedere quanto si e migliorati.
    private enum Pagina: String, PaginaLaterale {
        case adesso, andamento, obiettivi, sessioni, dati

        var id: String { rawValue }

        var titolo: String {
            switch self {
            case .adesso: "A che punto sei"
            case .andamento: "Come sta andando"
            case .obiettivi: "Obiettivi"
            case .sessioni: "Le ultime volte"
            case .dati: "Porta via i dati"
            }
        }

        var simbolo: String {
            switch self {
            case .adesso: "star.fill"
            case .andamento: "chart.line.uptrend.xyaxis"
            case .obiettivi: "trophy.fill"
            case .sessioni: "calendar"
            case .dati: "square.and.arrow.up.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            intestazione
                .padding(.horizontal, a11y.size(28))
                .padding(.vertical, a11y.size(16))
            Divider()
            HStack(spacing: 0) {
                ElencoPagine(scelta: $pagina, a11y: a11y, palette: palette)
                Divider()
                ScrollView {
                    paginaCorrente
                        .padding(a11y.size(28))
                        .frame(maxWidth: 860, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(palette.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var paginaCorrente: some View {
        VStack(alignment: .leading, spacing: a11y.size(20)) {
            switch pagina {
            case .adesso:
                sezionelivello
                sezioneSerie
                rigaRiassuntiva
            case .andamento:
                sezioneGrafici
            case .obiettivi:
                sezioneObiettivi
            case .sessioni:
                sezioneSessioniRecenti
            case .dati:
                piedePiePage
            }
        }
    }

    // MARK: - Intestazione

    private var intestazione: some View {
        HStack(alignment: .center, spacing: a11y.size(12)) {
            VStack(alignment: .leading, spacing: 4) {
                Text("I tuoi progressi")
                    .font(a11y.typeface.font(size: a11y.size(28), weight: .bold))
                    .foregroundStyle(palette.foreground)
                if !bambino.name.isEmpty {
                    Text(bambino.name)
                        .font(a11y.typeface.font(size: a11y.size(16), weight: .regular))
                        .foregroundStyle(palette.muted)
                }
            }
            Spacer()
            Button(action: onClose) {
                Text("Chiudi")
                    .font(a11y.typeface.font(size: a11y.size(15), weight: .semibold))
                    .foregroundStyle(palette.foreground)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            // Le altre schermate si chiudono con Esc. Una che non lo fa
            // obbliga a cercare il mouse, e chi il mouse non lo usa resta
            // dentro.
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Chiudi i tuoi progressi")
        }
    }

    // MARK: - Livello e XP

    private var sezionelivello: some View {
        let lv      = Gamification.level(xp: bambino.xp)
        let nome    = Gamification.levelName(lv)
        let prog    = Gamification.progressInLevel(bambino.xp)
        let xpInLv  = Gamification.xpInLevel(bambino.xp)

        return VStack(alignment: .leading, spacing: a11y.size(10)) {
            HStack(alignment: .center, spacing: a11y.size(14)) {
                // Il distintivo dà una faccia alla fascia di livello: non più
                // solo un numero, ma un simbolo che cresce di grado salendo.
                DistintivoLivello(livello: lv, diametro: 60, a11y: a11y, palette: palette)

                VStack(alignment: .leading, spacing: a11y.size(2)) {
                    Text("Livello \(lv)")
                        .font(a11y.typeface.font(size: a11y.size(40), weight: .heavy))
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                    Text(nome)
                        .font(a11y.typeface.font(size: a11y.size(22), weight: .semibold))
                        .foregroundStyle(palette.foreground)
                        .accessibilityHidden(true)
                }
            }
            // La barra mostra visivamente quanto manca al prossimo livello.
            ProgressView(value: prog)
                .tint(palette.accent)
            if !a11y.hideScore {
                Text("\(xpInLv) / \(Gamification.xpPerLevel) XP verso il livello \(lv + 1)")
                    .font(a11y.typeface.font(size: a11y.size(13), weight: .regular))
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(a11y.size(20))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // Un unico elemento VoiceOver che legge tutto d'un fiato.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Livello \(lv), \(nome)")
        .accessibilityValue(
            a11y.hideScore
                ? "Stai avanzando"
                : "\(xpInLv) su \(Gamification.xpPerLevel) punti, \(Int(prog * 100)) percento verso il livello successivo"
        )
    }

    // MARK: - Serie di giorni

    private var sezioneSerie: some View {
        let streak = bambino.streakCurrent
        let rec    = bambino.streakLongest

        return HStack(spacing: a11y.size(14)) {
            // La fiamma arancione indica la serie attiva; il significato è
            // ribadito dal testo così chi non distingue i colori capisce lo stesso.
            Image(systemName: streak > 0 ? "flame.fill" : "calendar")
                .font(a11y.typeface.font(size: a11y.size(30), weight: .bold))
                .foregroundStyle(streak > 0 ? Color.orange : palette.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if streak == 0 {
                    Text("Comincia oggi la tua serie")
                        .font(a11y.typeface.font(size: a11y.size(18), weight: .semibold))
                        .foregroundStyle(palette.foreground)
                    Text("Ogni giorno conta")
                        .font(a11y.typeface.font(size: a11y.size(14), weight: .regular))
                        .foregroundStyle(palette.muted)
                } else {
                    Text("\(streak) \(streak == 1 ? "giorno di fila" : "giorni di fila")")
                        .font(a11y.typeface.font(size: a11y.size(20), weight: .bold))
                        .foregroundStyle(palette.foreground)
                    if rec > 0 {
                        Text("Record: \(rec) \(rec == 1 ? "giorno" : "giorni")")
                            .font(a11y.typeface.font(size: a11y.size(14), weight: .regular))
                            .foregroundStyle(palette.muted)
                    }
                }
            }
            Spacer()
        }
        .padding(a11y.size(18))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etichettaVoiceOverSerie)
    }

    private var etichettaVoiceOverSerie: String {
        let s  = bambino.streakCurrent
        let pl = s == 1 ? "giorno di fila" : "giorni di fila"
        guard s > 0 else {
            return "Serie: nessun giorno consecutivo ancora. Puoi cominciare oggi."
        }
        let rec   = bambino.streakLongest
        let recPl = rec == 1 ? "giorno" : "giorni"
        return "Serie attiva: \(s) \(pl). Record personale: \(rec) \(recPl)."
    }

    // MARK: - Riquadri riassuntivi

    private var rigaRiassuntiva: some View {
        let count   = sessioni.count
        let correct = sessioni.reduce(0) { $0 + $1.correct }
        let bestMs  = sessioni.compactMap(\.thresholdMs).min()

        return HStack(spacing: a11y.size(10)) {
            _RiquadroRiassuntivo(
                simbolo: "checkmark.seal.fill",
                coloreSimbolo: palette.ok,
                etichetta: "Sessioni",
                valore: a11y.hideScore ? conteggioQualitativo(count, .sessioni) : "\(count)",
                sottotitolo: nil,
                a11y: a11y, palette: palette
            )
            .accessibilityLabel(
                "Sessioni completate: \(a11y.hideScore ? conteggioQualitativo(count, .sessioni) : String(count))"
            )

            _RiquadroRiassuntivo(
                simbolo: "text.word.spacing",
                coloreSimbolo: palette.accent,
                etichetta: "Parole giuste",
                valore: a11y.hideScore ? conteggioQualitativo(correct, .parole) : "\(correct)",
                sottotitolo: nil,
                a11y: a11y, palette: palette
            )
            .accessibilityLabel(
                "Parole lette correttamente: \(a11y.hideScore ? conteggioQualitativo(correct, .parole) : String(correct))"
            )

            if let ms = bestMs {
                _RiquadroRiassuntivo(
                    simbolo: "timer",
                    coloreSimbolo: palette.accent,
                    etichetta: "Il tuo record",
                    valore: a11y.hideScore ? "fulmine" : "\(Int(ms))",
                    sottotitolo: a11y.hideScore ? nil : "millesimi di secondo",
                    a11y: a11y, palette: palette
                )
                .accessibilityLabel(
                    a11y.hideScore
                        ? "Record di velocità: velocissimo"
                        : "Record di velocità: \(Int(ms)) millesimi di secondo"
                )
            }
        }
    }

    // MARK: - Grafici

    @ViewBuilder
    private var sezioneGrafici: some View {
        if sessioniGrafico.count < 2 {
            // Stato vuoto invitante: non un errore, ma un'opportunità.
            HStack(spacing: a11y.size(14)) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(a11y.typeface.font(size: a11y.size(30), weight: .light))
                    .foregroundStyle(palette.muted)
                    .accessibilityHidden(true)
                Text("Fai un'altra sessione e qui comparirà il tuo andamento")
                    .font(a11y.typeface.font(size: a11y.size(15), weight: .regular))
                    .foregroundStyle(palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(a11y.size(24))
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            VStack(alignment: .leading, spacing: a11y.size(12)) {
                graficoAccuratezza
                graficoSoglia
            }
        }
    }

    private var graficoAccuratezza: some View {
        VStack(alignment: .leading, spacing: a11y.size(8)) {
            Text("Precisione nel tempo")
                .font(a11y.typeface.font(size: a11y.size(17), weight: .semibold))
                .foregroundStyle(palette.foreground)

            Chart(puntiGrafico) { p in
                LineMark(
                    x: .value("Sessione", p.id),
                    y: .value("Precisione %", p.accuratezza)
                )
                .foregroundStyle(palette.ok)
                PointMark(
                    x: .value("Sessione", p.id),
                    y: .value("Precisione %", p.accuratezza)
                )
                .foregroundStyle(palette.ok)
            }
            .chartYScale(domain: 0...100)
            .chartYAxisLabel("Parole giuste %")
            .frame(minHeight: 160)
        }
        .padding(a11y.size(18))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grafico della precisione nel tempo. Le sessioni più recenti sono a destra.")
    }

    private var graficoSoglia: some View {
        let conSoglia = puntiGrafico.filter { $0.sogliaMs != nil }

        return VStack(alignment: .leading, spacing: a11y.size(8)) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Soglia di velocità nel tempo")
                    .font(a11y.typeface.font(size: a11y.size(17), weight: .semibold))
                    .foregroundStyle(palette.foreground)
                // Nota obbligatoria: il grafico migliora verso il basso, non verso l'alto.
                Text("↓  più in basso = più bravo (meno millisecondi = più veloce)")
                    .font(a11y.typeface.font(size: a11y.size(12), weight: .regular))
                    .foregroundStyle(palette.muted)
            }

            if conSoglia.isEmpty {
                Text("Nessun dato di soglia ancora. La modalità adattiva li raccoglie in automatico.")
                    .font(a11y.typeface.font(size: a11y.size(14), weight: .regular))
                    .foregroundStyle(palette.muted)
                    .padding(.vertical, a11y.size(14))
            } else {
                Chart(conSoglia) { p in
                    LineMark(
                        x: .value("Sessione", p.id),
                        y: .value("ms", p.sogliaMs ?? 0)
                    )
                    .foregroundStyle(palette.accent)
                    PointMark(
                        x: .value("Sessione", p.id),
                        y: .value("ms", p.sogliaMs ?? 0)
                    )
                    .foregroundStyle(palette.accent)
                }
                .chartYAxisLabel("Millisecondi")
                .frame(minHeight: 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Grafico della soglia di velocità. Valori più bassi indicano lettura più rapida."
                )
            }
        }
        .padding(a11y.size(18))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Obiettivi

    private let colonneObiettivi = [GridItem(.adaptive(minimum: 144, maximum: 220))]

    private var sezioneObiettivi: some View {
        VStack(alignment: .leading, spacing: a11y.size(12)) {
            Text("Obiettivi")
                .font(a11y.typeface.font(size: a11y.size(20), weight: .bold))
                .foregroundStyle(palette.foreground)

            LazyVGrid(columns: colonneObiettivi, spacing: a11y.size(10)) {
                ForEach(Gamification.all) { a in
                    _CellaObiettivo(
                        obiettivo: a,
                        sbloccato: bambino.unlockedAchievements.contains(a.id),
                        a11y: a11y,
                        palette: palette
                    )
                }
            }
        }
        .padding(a11y.size(18))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Sessioni recenti

    private var sezioneSessioniRecenti: some View {
        VStack(alignment: .leading, spacing: a11y.size(6)) {
            Text("Sessioni recenti")
                .font(a11y.typeface.font(size: a11y.size(20), weight: .bold))
                .foregroundStyle(palette.foreground)
                .padding(.bottom, a11y.size(4))

            if sessioni.isEmpty {
                Text("Ancora nessuna sessione completata. La prima è quella che conta di più.")
                    .font(a11y.typeface.font(size: a11y.size(15), weight: .regular))
                    .foregroundStyle(palette.muted)
                    .padding(.vertical, a11y.size(12))
            } else {
                ForEach(Array(sessioni.prefix(10))) { sessione in
                    VStack(spacing: 0) {
                        _RigaSessione(
                            sessione: sessione,
                            aperta: sessioneEspansa == sessione.id,
                            a11y: a11y,
                            palette: palette
                        ) {
                            // Toggla l'espansione; rispetta reducedMotion.
                            let prossimo: UUID? =
                                sessioneEspansa == sessione.id ? nil : sessione.id
                            if a11y.reducedMotion {
                                sessioneEspansa = prossimo
                            } else {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    sessioneEspansa = prossimo
                                }
                            }
                        }
                        Divider().opacity(0.35)
                    }
                }
            }
        }
        .padding(a11y.size(18))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Piede adulto

    private var piedePiePage: some View {
        HStack(spacing: a11y.size(10)) {
            Button {
                let data = Exporter.pdf(sessions: store.currentHistory, learner: store.current)
                let nome = bambino.name.isEmpty ? "bambino" : bambino.name
                Exporter.save(data: data, suggested: "progressi-\(nome).pdf")
            } label: {
                Label("Esporta PDF", systemImage: "doc.fill")
                    .font(a11y.typeface.font(size: a11y.size(14), weight: .regular))
                    .foregroundStyle(palette.foreground)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                guard let ultima = sessioni.first else { return }
                let csv  = Exporter.csv(ultima, learner: store.current)
                let nome = bambino.name.isEmpty ? "sessione" : bambino.name
                Exporter.save(text: csv, suggested: "sessione-\(nome).csv")
            } label: {
                Label("Esporta CSV", systemImage: "tablecells")
                    .font(a11y.typeface.font(size: a11y.size(14), weight: .regular))
                    .foregroundStyle(palette.foreground)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Button {
                mostraConfermaReset = true
            } label: {
                Label("Cancella lo storico", systemImage: "trash")
                    .font(a11y.typeface.font(size: a11y.size(14), weight: .regular))
                    .foregroundStyle(palette.wrong)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
        }
        .padding(a11y.size(14))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .confirmationDialog(
            "Cancellare tutto lo storico\(bambino.name.isEmpty ? "" : " di \(bambino.name)")?",
            isPresented: $mostraConfermaReset,
            titleVisibility: .visible
        ) {
            Button("Sì, cancella tutto", role: .destructive) {
                store.deleteHistory()
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Questa azione non si può annullare. Le sessioni passate andranno perse.")
        }
    }

    // MARK: - Utilità

    private enum _Contesto { case sessioni, parole }

    // Traduzione qualitativa dei numeri: onesta, mai colpevolizzante.
    private func conteggioQualitativo(_ n: Int, _ ctx: _Contesto) -> String {
        switch ctx {
        case .sessioni:
            switch n {
            case 0:       return "nessuna ancora"
            case 1:       return "una"
            case 2...4:   return "alcune"
            case 5...9:   return "tante"
            default:      return "moltissime"
            }
        case .parole:
            switch n {
            case 0:       return "nessuna ancora"
            case 1...9:   return "poche"
            case 10...49: return "tante"
            case 50...199: return "moltissime"
            default:      return "tantissime"
            }
        }
    }
}

// MARK: - Punto dati per i grafici

/// Struttura leggera usata solo da Chart: evita di calcolare due volte gli stessi valori.
private struct _PuntoGrafico: Identifiable {
    let id: Int
    let accuratezza: Double   // 0...100
    let sogliaMs: Double?
}

// MARK: - Riquadro riassuntivo

private struct _RiquadroRiassuntivo: View {
    let simbolo: String
    let coloreSimbolo: Color
    let etichetta: String
    let valore: String
    let sottotitolo: String?
    let a11y: A11ySettings
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: a11y.size(6)) {
            Image(systemName: simbolo)
                .font(a11y.typeface.font(size: a11y.size(22), weight: .semibold))
                .foregroundStyle(coloreSimbolo)
                .accessibilityHidden(true)
            Text(valore)
                .font(a11y.typeface.font(size: a11y.size(28), weight: .heavy))
                .foregroundStyle(palette.foreground)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(etichetta)
                .font(a11y.typeface.font(size: a11y.size(13), weight: .regular))
                .foregroundStyle(palette.muted)
            if let sub = sottotitolo {
                Text(sub)
                    .font(a11y.typeface.font(size: a11y.size(12), weight: .regular))
                    .foregroundStyle(palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(a11y.size(16))
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Cella obiettivo

private struct _CellaObiettivo: View {
    let obiettivo: Achievement
    let sbloccato: Bool
    let a11y: A11ySettings
    let palette: Palette

    var body: some View {
        VStack(spacing: a11y.size(8)) {
            // Il distintivo mostra sempre il simbolo dell'obiettivo — tenue
            // finché è da conquistare, pieno quando è tuo — invece del vecchio
            // lucchetto uguale per tutti.
            DistintivoObiettivo(
                simbolo: obiettivo.symbol,
                conquistato: sbloccato,
                a11y: a11y,
                palette: palette
            )

            Text(obiettivo.title)
                .font(a11y.typeface.font(size: a11y.size(13), weight: .semibold))
                .foregroundStyle(sbloccato ? palette.foreground : palette.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Il suggerimento è sempre visibile: il bambino deve sapere a cosa puntare.
            Text(obiettivo.hint)
                .font(a11y.typeface.font(size: a11y.size(11), weight: .regular))
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(a11y.size(12))
        .frame(maxWidth: .infinity)
        .background(palette.surface.opacity(sbloccato ? 1.0 : 0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            // La cornice della cella conquistata resta leggibile anche senza
            // colore grazie allo spessore: in modalità calma niente oro acceso.
            if sbloccato {
                let cornice = a11y.calmMode
                    ? palette.foreground.opacity(0.5)
                    : Color(red: 0.85, green: 0.63, blue: 0.10).opacity(0.55)
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(cornice, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            sbloccato
                ? "Obiettivo raggiunto: \(obiettivo.title). \(obiettivo.hint)"
                : "Obiettivo ancora da raggiungere: \(obiettivo.title). \(obiettivo.hint)"
        )
    }
}

// MARK: - Riga sessione recente

private struct _RigaSessione: View {
    let sessione: SessionRecord
    let aperta: Bool
    let a11y: A11ySettings
    let palette: Palette
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                rigaPrincipale
                if aperta { dettaglioParole }
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(aperta ? "Tocca per chiudere i dettagli" : "Tocca per vedere le parole da ripassare")
    }

    private var rigaPrincipale: some View {
        HStack(spacing: a11y.size(10)) {
            // Indicatore di esito: forma + colore, mai solo il colore.
            let buono = sessione.total > 0 && sessione.accuracy >= 0.6
            Image(systemName: buono ? "checkmark.circle.fill" : "xmark.square.fill")
                .font(a11y.typeface.font(size: a11y.size(18), weight: .regular))
                .foregroundStyle(buono ? palette.ok : palette.wrong)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(dataItaliana(sessione.date))
                    .font(a11y.typeface.font(size: a11y.size(15), weight: .semibold))
                    .foregroundStyle(palette.foreground)
                HStack(spacing: a11y.size(6)) {
                    Label(sessione.mode.label, systemImage: sessione.mode.symbol)
                        .font(a11y.typeface.font(size: a11y.size(13), weight: .regular))
                        .foregroundStyle(palette.muted)
                    Text("·")
                        .font(a11y.typeface.font(size: a11y.size(13), weight: .regular))
                        .foregroundStyle(palette.muted)
                    Label(sessione.level.title, systemImage: sessione.level.symbol)
                        .font(a11y.typeface.font(size: a11y.size(13), weight: .regular))
                        .foregroundStyle(palette.muted)
                }
            }

            Spacer()

            // "12 su 15" è più leggibile di una percentuale per i bambini.
            Text("\(sessione.correct) su \(sessione.total)")
                .font(a11y.typeface.font(size: a11y.size(15), weight: .semibold))
                .foregroundStyle(palette.foreground)

            Image(systemName: aperta ? "chevron.up" : "chevron.down")
                .font(a11y.typeface.font(size: a11y.size(12), weight: .regular))
                .foregroundStyle(palette.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, a11y.size(10))
    }

    @ViewBuilder
    private var dettaglioParole: some View {
        let mancate = sessione.missedWords
        VStack(alignment: .leading, spacing: a11y.size(6)) {
            if mancate.isEmpty {
                Text("Nessuna parola mancata — ottimo lavoro")
                    .font(a11y.typeface.font(size: a11y.size(13), weight: .regular))
                    .foregroundStyle(palette.muted)
            } else {
                Text("Parole da ripassare:")
                    .font(a11y.typeface.font(size: a11y.size(13), weight: .semibold))
                    .foregroundStyle(palette.muted)
                // Chips orizzontali: scannable a colpo d'occhio.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80))],
                    spacing: a11y.size(6)
                ) {
                    ForEach(Array(mancate.enumerated()), id: \.offset) { _, parola in
                        Text(parola)
                            .font(a11y.typeface.font(size: a11y.size(14), weight: .semibold))
                            .foregroundStyle(palette.foreground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(palette.background)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
        }
        .padding(.bottom, a11y.size(10))
    }

    private func dataItaliana(_ data: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(data)     { return "oggi" }
        if cal.isDateInYesterday(data) { return "ieri" }
        let fmt = DateFormatter()
        fmt.locale     = Locale(identifier: "it_IT")
        fmt.dateFormat = "d MMMM"
        return fmt.string(from: data)
    }
}
