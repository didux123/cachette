#!/usr/bin/env python3
"""Génère la base SQLite embarquée de résolution CIP13 → médicament.

Source : BDPM (Base de Données Publique des Médicaments), open data,
fichiers TSV encodés Windows-1252, sans en-tête, mis à jour ~mensuellement.

Usage :
    python3 Tools/bdpm_build.py            # télécharge (cache) + génère
    python3 Tools/bdpm_build.py --offline  # utilise uniquement le cache
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sqlite3
import sys
import urllib.request
from pathlib import Path

BASE_URL = "https://base-donnees-publique.medicaments.gouv.fr/download/file/"
FICHIERS = ["CIS_bdpm.txt", "CIS_CIP_bdpm.txt"]

RACINE = Path(__file__).resolve().parent.parent
CACHE = Path(__file__).resolve().parent / ".cache"
SORTIE = RACINE / "Cachette" / "Resources" / "bdpm.sqlite"

# « boîte de 30 comprimés », « 5 stylos préremplis de 3 ml », « par 90 gélules »…
RE_UNITES = re.compile(
    r"(?:de|par)?\s*(\d{1,4})\s*"
    r"(comprim|g[ée]lule|capsule|sachet|ampoule|stylo|seringue|dose|film|"
    r"ovule|suppositoire|cartouche|bande|compresse|unidose|implant|patch|"
    r"r[ée]cipient|flacon)",
    re.IGNORECASE,
)


def telecharger(nom: str, offline: bool) -> Path:
    CACHE.mkdir(exist_ok=True)
    destination = CACHE / nom
    if offline:
        if not destination.exists():
            sys.exit(f"--offline mais {destination} absent")
        return destination
    url = BASE_URL + nom
    print(f"↓ {url}")
    requete = urllib.request.Request(url, headers={"User-Agent": "Cachette-build/1.0"})
    with urllib.request.urlopen(requete, timeout=120) as reponse:
        destination.write_bytes(reponse.read())
    print(f"  → {destination.stat().st_size / 1e6:.1f} Mo")
    return destination


def lire_tsv(chemin: Path) -> list[list[str]]:
    texte = chemin.read_bytes().decode("windows-1252")
    return [
        [c.strip() for c in ligne.split("\t")]
        for ligne in texte.splitlines()
        if ligne.strip()
    ]


def extraire_unites(libelle: str) -> int | None:
    """Nombre d'unités par boîte, déduit du libellé de présentation.

    On prend la PLUS GRANDE quantité trouvée : « 5 stylos de 3 ml » → 5,
    « plaquette(s) de 30 comprimés » → 30.
    """
    candidats = [int(m.group(1)) for m in RE_UNITES.finditer(libelle)]
    candidats = [c for c in candidats if 1 <= c <= 1000]
    return max(candidats) if candidats else None


def construire(offline: bool) -> None:
    cis_path = telecharger("CIS_bdpm.txt", offline)
    cip_path = telecharger("CIS_CIP_bdpm.txt", offline)

    # CIS_bdpm : 0=CIS 1=dénomination 2=forme 3=voies 4=statut AMM … 6=état commercialisation
    medicaments: dict[str, str] = {}
    for champs in lire_tsv(cis_path):
        if len(champs) >= 2:
            medicaments[champs[0]] = champs[1]

    # CIS_CIP : 0=CIS 1=CIP7 2=libellé présentation 3=statut 4=état commercialisation … 6=CIP13
    lignes = []
    sans_cip13 = 0
    for champs in lire_tsv(cip_path):
        if len(champs) < 7:
            continue
        cis, libelle, etat, cip13 = champs[0], champs[2], champs[4], champs[6]
        if not re.fullmatch(r"\d{13}", cip13):
            sans_cip13 += 1
            continue
        denomination = medicaments.get(cis)
        if not denomination:
            continue
        lignes.append((cip13, cis, denomination, libelle, etat, extraire_unites(libelle)))

    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    SORTIE.unlink(missing_ok=True)
    connexion = sqlite3.connect(SORTIE)
    connexion.executescript(
        """
        PRAGMA journal_mode = DELETE;
        CREATE TABLE presentation(
            cip13 TEXT PRIMARY KEY,
            cis TEXT NOT NULL,
            denomination TEXT NOT NULL,
            libelle_presentation TEXT,
            etat_commercialisation TEXT,
            unites_par_boite INTEGER
        );
        CREATE TABLE meta(cle TEXT PRIMARY KEY, valeur TEXT);
        """
    )
    connexion.executemany(
        "INSERT OR REPLACE INTO presentation VALUES (?,?,?,?,?,?)", lignes
    )
    connexion.execute(
        "INSERT INTO meta VALUES ('date_snapshot', ?)",
        (dt.date.today().isoformat(),),
    )
    connexion.execute("INSERT INTO meta VALUES ('version_schema', '1')")
    connexion.commit()
    connexion.execute("VACUUM")
    connexion.close()

    taille = SORTIE.stat().st_size / 1e6
    print(f"✓ {SORTIE.name} : {len(lignes)} présentations, {taille:.1f} Mo "
          f"({sans_cip13} lignes sans CIP13 ignorées)")


if __name__ == "__main__":
    parseur = argparse.ArgumentParser()
    parseur.add_argument("--offline", action="store_true")
    construire(parseur.parse_args().offline)
