# 🚆 CFF Ponctualité

Pipeline de données sur la ponctualité des transports publics suisses, construit à partir des
horaires réellement observés publiés chaque jour sur [opentransportdata.swiss](https://opentransportdata.swiss).

> 🚧 Projet en cours de construction — avancement documenté étape par étape.

## Objectif

Collecter quotidiennement les « Ist-Daten » (heure prévue vs heure réelle de chaque arrêt
du réseau suisse), les historiser au-delà de la fenêtre de 50 jours du portail, et analyser
la ponctualité des trains, notamment en Suisse romande et en lien avec la météo.

## Architecture cible

```
API CKAN opendata.swiss → Python → GCS (Parquet, partitions Hive)
  → BigQuery (partitionné par jour, filtre de partition obligatoire) → dbt → dashboard

Orchestration : Airflow · Région : europe-west6 (Zurich)
```


## Avancement

- [x] Ingestion d'un fichier quotidien via l'API CKAN (téléchargement en streaming, idempotent)
- [x] Exploration avec DuckDB : schéma, volumes, qualité des données
- [x] Couches raw (texte brut) et staging (typage explicite, colonnes en anglais, tests de conversion)
- [x] Stockage Parquet sur GCS et chargement BigQuery
- [x] Pipeline d'un jour de bout en bout et rattrapage de l'historique disponible (50 jours)
- [ ] Orchestration quotidienne avec Airflow
- [ ] Modèles dbt et tests de qualité
- [ ] Jointure avec les données MeteoSwiss
- [ ] Dashboard

## Chiffres clés

**Historique chargé** : 50 jours (20 août → 8 octobre 2026), 121,9 millions de lignes

**Un jour type** : 2,6 millions de lignes en semaine, 1,7 million le dimanche

**Stockage**
- CSV → Parquet ZSTD : ×24 plus léger (≈ 660 Mo → 28 Mo par jour de semaine)
- BigQuery : 35,4 Go logiques → 3,0 Go physiques (×12), facturation au stockage compressé

**Qualité**
- 88 % des heures d'arrivée réellement mesurées
- 0 échec de conversion des dates après typage explicite
- Contrôle automatique : nombre de lignes BigQuery = nombre de lignes du fichier, pour chaque jour

## Décisions de conception

Voir [docs/decisions.md](docs/decisions.md).

## Lancer l'ingestion

Prérequis : un projet GCP avec un bucket GCS et un dataset BigQuery en `europe-west6`,
et `gcloud auth application-default login` effectué.

    python -m venv .venv && source .venv/bin/activate
    pip install -r requirements.txt

    # Un jour de bout en bout : téléchargement → Parquet → GCS → BigQuery
    python ingestion/pipeline.py 2026-10-08

    # Tous les jours disponibles qui manquent (--dry-run pour voir le plan sans rien lancer)
    python ingestion/backfill.py --dry-run
    python ingestion/backfill.py

Aide-mémoire complet des commandes : [docs/aide-memoire_commandes_bash.md](docs/aide-memoire_commandes_bash.md).

