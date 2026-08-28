#!/usr/bin/env python3
"""Rende il progetto Xcode generato identico byte per byte a ogni generazione.

Perché serve: xcodegen assegna a quasi tutti gli oggetti un identificatore
calcolato dal percorso del file, quindi sempre uguale. A cinque oggetti però
— quelli legati a Versione.xcconfig, che è un file generato e non elencato fra
i file del progetto — assegna un numero casuale nuovo a ogni giro, con la
forma «TEMP_<numero casuale>».

Cinque righe su settemila, ma bastano a rendere il progetto diverso da sé
stesso: rigenerandolo due volte di fila git segnala una modifica che nessuno
ha fatto. Ora che il progetto sta nel repository (serve a Xcode Cloud, che
pretende di trovarlo già pronto) quel rumore diventerebbe una modifica falsa
a ogni apertura, e soprattutto renderebbe impossibile il controllo che verifica
che il progetto committato corrisponda ancora a project.yml.

Qui i numeri casuali vengono sostituiti in ordine di prima apparizione con
TEMP_0001, TEMP_0002... L'ordine lo decide xcodegen ed è sempre lo stesso,
quindi il risultato è stabile su qualsiasi Mac e su GitHub.
"""

import re
import sys
from pathlib import Path

PBXPROJ = Path(__file__).resolve().parent.parent / "MirrorScopio.xcodeproj" / "project.pbxproj"
CASUALE = re.compile(r'TEMP_[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')


def main() -> int:
    if not PBXPROJ.exists():
        print(f"Manca {PBXPROJ}: genera prima il progetto con scripts/genera-progetto.sh", file=sys.stderr)
        return 1

    testo = PBXPROJ.read_text(encoding="utf-8")

    numerati: dict[str, str] = {}
    for trovato in CASUALE.findall(testo):
        if trovato not in numerati:
            numerati[trovato] = f"TEMP_{len(numerati) + 1:04d}"

    if not numerati:
        return 0

    for casuale, stabile in numerati.items():
        testo = testo.replace(casuale, stabile)

    PBXPROJ.write_text(testo, encoding="utf-8")
    print(f"Progetto stabilizzato: {len(numerati)} identificatori casuali resi fissi")
    return 0


if __name__ == "__main__":
    sys.exit(main())
