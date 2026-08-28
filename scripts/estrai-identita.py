#!/usr/bin/env python3
"""Tiene una sola identità fra quelle esportate dal portachiavi.

`security export -t identities` tira fuori tutto quello che c'è nel portachiavi
«login»: certificati di sviluppo, installer, perfino un «localhost». A GitHub
serve solo il «Developer ID Application» con cui si firma l'app, e mandargli il
resto significa moltiplicare le chiavi private che si possono perdere.

Uso:  estrai-identita.py <cartella-temporanea> <nome dell'identità>

Legge `tutte.pem` dentro la cartella e ci scrive accanto `solo.crt` e
`solo.key`. In caso di guaio stampa il motivo e esce con errore.
"""
import os
import re
import subprocess
import sys

INIZIO_FINE = (
    ("-----BEGIN CERTIFICATE-----", "-----END CERTIFICATE-----"),
    ("-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----"),
)


def openssl(args: list[str], testo: str) -> str:
    return subprocess.run(args, input=testo, capture_output=True, text=True).stdout


def main() -> int:
    if len(sys.argv) != 3:
        print("uso: estrai-identita.py <cartella> <nome identità>")
        return 2
    cartella, identita = sys.argv[1], sys.argv[2]

    pem = open(os.path.join(cartella, "tutte.pem")).read()
    certificati: list[str] = []
    chiavi: list[str] = []
    for sacchetto in re.split(r"(?=Bag Attributes)", pem):
        for (inizio, fine), dove in zip(INIZIO_FINE, (certificati, chiavi)):
            if inizio in sacchetto:
                a = sacchetto.index(inizio)
                b = sacchetto.index(fine) + len(fine)
                dove.append(sacchetto[a:b] + "\n")

    # Il nome completo porta dietro il codice del team fra parentesi, che nel
    # soggetto del certificato compare scritto in un altro modo.
    nome = identita.split(" (")[0]
    certificato = next(
        (c for c in certificati
         if nome in openssl(["openssl", "x509", "-noout", "-subject"], c)),
        None,
    )
    if certificato is None:
        print("nel portachiavi non c'è nessun certificato «%s»" % nome)
        return 1

    # La chiave giusta si riconosce dal modulo, non dall'ordine in cui compare:
    # fidarsi dell'ordine vuol dire rischiare di spedire a GitHub la chiave
    # privata di un altro certificato.
    modulo = openssl(["openssl", "x509", "-noout", "-modulus"], certificato).strip()
    chiave = next(
        (k for k in chiavi
         if openssl(["openssl", "rsa", "-noout", "-modulus"], k).strip() == modulo),
        None,
    )
    if chiave is None:
        print("il certificato «%s» c'è, ma la sua chiave privata no" % nome)
        return 1

    open(os.path.join(cartella, "solo.crt"), "w").write(certificato)
    open(os.path.join(cartella, "solo.key"), "w").write(chiave)
    print("ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
