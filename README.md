# 🚆 CFF Ponctualité

Pipeline de données sur la ponctualité des transports publics suisses, construit à partir des
horaires réellement observés publiés chaque jour sur [opentransportdata.swiss](https://opentransportdata.swiss).

> 🚧 Projet en cours de construction — avancement documenté étape par étape.

## Objectif

Collecter quotidiennement les « Ist-Daten » (heure prévue vs heure réelle de chaque arrêt
du réseau suisse), les historiser au-delà de la fenêtre de 50 jours du portail, et analyser
la ponctualité des trains, notamment en Suisse romande et en lien avec la météo.

## Architecture cible

API CKAN opendata.swiss → Python → GCS (Parquet) → BigQuery (partitionné) → dbt → dashboard
Orchestration : Airflow · Région : europe-west6 (Zurich)

## Avancement

- [x] Ingestion d'un fichier quotidien via l'API CKAN (téléchargement en streaming, idempotent)
- [x] Exploration avec DuckDB : schéma, volumes, qualité des données
- [x] Couches raw (texte brut) et staging (typage explicite, colonnes en anglais, tests de conversion)
- [ ] Stockage Parquet sur GCS et chargement BigQuery
- [ ] Orchestration quotidienne avec Airflow
- [ ] Modèles dbt et tests de qualité
- [ ] Jointure avec les données MeteoSwiss
- [ ] Dashboard

## Chiffres clés (un dimanche)

- 409 Mo de CSV, 1,7 million de lignes
- 88 % des heures d'arrivée réellement mesurées
- 0 échec de conversion des dates après typage explicite

## Décisions de conception

Voir [docs/decisions.md](docs/decisions.md).

## Lancer l'ingestion

    python -m venv .venv && source .venv/bin/activate
    pip install requests duckdb
    python ingestion/download_istdaten.py 2026-10-04
