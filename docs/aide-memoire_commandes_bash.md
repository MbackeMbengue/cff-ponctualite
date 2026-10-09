# Aide-mémoire — commandes du projet CFF Ponctualité

Toutes les commandes se lancent **depuis la racine du projet** :
`/home/naylu/Documents/cff-ponctualite`

---

## 1. Démarrer une session de travail

À faire **à chaque fois** que tu ouvres un nouveau terminal.

| Commande | Objectif |
|---|---|
| `cd ~/Documents/cff-ponctualite` | Se placer à la racine du projet |
| `source .venv/bin/activate` | **Activer l'environnement virtuel** — `(.venv)` doit apparaître au début de la ligne |
| `gcloud config set project cff-ponctualite` | S'assurer que GCP pointe sur le bon projet (et pas sur `fred-pipeline`) |
| `git pull` | Récupérer la dernière version du dépôt si tu as travaillé ailleurs |

Pour sortir de l'environnement virtuel : `deactivate`

Vérifications rapides :

```bash
which python3          # doit finir par .venv/bin/python3
gcloud config list     # doit afficher project = cff-ponctualite
git status             # état des fichiers modifiés
```

---

## 2. Routine Git

| Commande | Objectif |
|---|---|
| `git status` | Voir ce qui a changé — vérifier qu'aucun fichier de `data/` n'apparaît |
| `git add <fichier>` | Préparer un fichier pour le commit |
| `git commit -m "message"` | Enregistrer une étape dans l'historique |
| `git push` | Envoyer les commits sur GitHub |
| `git log --oneline` | Voir l'historique des commits |

Règle : **un commit à chaque étape qui fonctionne**.

---

## 3. Installation (déjà faite — utile pour une nouvelle machine)

```bash
git clone https://github.com/MbackeMbengue/cff-ponctualite.git
cd cff-ponctualite
python3 -m venv .venv                  # créer l'environnement virtuel
source .venv/bin/activate              # l'activer
pip install -r requirements.txt        # installer toutes les dépendances
mkdir -p data/raw                      # dossier des données (ignoré par Git)
```

Après avoir installé un nouveau paquet :

```bash
pip install <paquet>
pip freeze > requirements.txt          # mettre à jour la liste des dépendances
```

---

## 4. Ingestion des données

| Commande | Objectif |
|---|---|
| `python3 ingestion/pipeline.py 2026-10-05` | **Traiter un jour de bout en bout** : téléchargement → Parquet → GCS → BigQuery, avec contrôle du nombre de lignes |
| `python3 ingestion/pipeline.py 2026-10-05 2026-10-06` | Traiter plusieurs jours à la suite |
| `python3 ingestion/backfill.py --dry-run` | Voir quels jours manquent dans BigQuery, **sans rien lancer** |
| `python3 ingestion/backfill.py` | Charger tous les jours disponibles qui manquent |
| `python3 ingestion/download_istdaten.py 2026-10-04` | Télécharger seulement le CSV d'un jour |
| `python3 ingestion/to_parquet.py 2026-10-04` | Convertir seulement un CSV déjà téléchargé en Parquet |

Lister les jours disponibles sur le portail (fenêtre glissante de 50 jours) :

```bash
python3 -c "
from ingestion.download_istdaten import list_resources
urls = sorted(r['url'].rsplit('/',1)[-1] for r in list_resources())
print(len(urls), 'fichiers'); print(urls[:3]); print(urls[-5:])
"
```

Lancer le rattrapage en arrière-plan : il continue même si le terminal est fermé,
et tous ses messages sont écrits dans un fichier journal.
```bash
nohup python3 -u ingestion/backfill.py > logs/backfill.log 2>&1 &
```

```bash
tail -f logs/backfill.log   # suivre le journal en direct (Ctrl+C arrête l'affichage, pas le script)
pgrep -af backfill          # vérifier que le script tourne encore
kill <numéro>               # arrêter le script (numéro donné par pgrep)
```
---

## 5. Explorer en local avec DuckDB

Lancer Python, puis :

```python
import duckdb
con = duckdb.connect("data/ist.duckdb")   # base locale, persiste entre les sessions
print(con.sql("SELECT COUNT(*) FROM ist_raw"))
```

Rappel : dans Python, le SQL s'écrit **toujours** entouré de `con.sql(""" ... """)`.
Les requêtes d'exploration sont dans `exploration/01_decouverte.sql`.

---

## 6. Google Cloud Storage (GCS)

| Commande | Objectif |
|---|---|
| `gcloud storage ls -l "gs://cff-ponctualite-raw/istdaten/**"` | Lister les fichiers Parquet stockés |
| `gcloud storage buckets list --format="value(name,location)"` | Vérifier le bucket et sa région (EUROPE-WEST6) |

---

## 7. BigQuery

Compter les lignes par jour (le filtre sur `_source_date` est **obligatoire**) :

```bash
bq query --use_legacy_sql=false \
  'SELECT _source_date, COUNT(*) AS n FROM `cff-ponctualite.cff_raw.istdaten` WHERE _source_date >= "2026-08-01" GROUP BY 1 ORDER BY 1'
```

| Commande | Objectif |
|---|---|
| `bq ls` | Lister les datasets |
| `bq show --format=prettyjson cff-ponctualite:cff_raw.istdaten \| grep -E '"numBytes"\|"numRows"'` | Taille et nombre de lignes de la table |
| `bq show --format=prettyjson cff-ponctualite:cff_raw.istdaten \| grep -iE 'physicalbytes\|logicalbytes'` | Comparer taille compressée et non compressée |
| `bq show --format=prettyjson cff-ponctualite:cff_raw \| grep -E 'storageBillingModel\|maxTimeTravelHours'` | Vérifier le modèle de facturation et le *time travel* |

---

## 8. Configuration GCP (déjà faite — pour mémoire)

| Commande | Objectif |
|---|---|
| `gcloud projects create cff-ponctualite --name="CFF Ponctualite"` | Créer un projet dédié |
| `gcloud billing projects link cff-ponctualite --billing-account=<ID>` | Rattacher la facturation (même compte que `fred-pipeline`) |
| `gcloud auth application-default login` | Donner aux scripts Python l'accès à GCP |
| `gcloud auth application-default set-quota-project cff-ponctualite` | Faire pointer les scripts Python sur ce projet |
| `gcloud services enable storage.googleapis.com bigquery.googleapis.com` | Activer GCS et BigQuery |
| `gcloud storage buckets create gs://cff-ponctualite-raw --location=europe-west6 --uniform-bucket-level-access` | Créer le bucket à Zurich |
| `bq --location=europe-west6 mk --dataset cff-ponctualite:cff_raw` | Créer le dataset à Zurich |
| `bq update --storage_billing_model=PHYSICAL cff-ponctualite:cff_raw` | Facturer le stockage compressé (÷5 sur le coût) |
| `bq update --max_time_travel_hours=48 cff-ponctualite:cff_raw` | Réduire le *time travel* à 48 h — **à vérifier : était en attente** |

Pour revenir travailler sur FRED : `gcloud config set project fred-pipeline`

---

## 9. Erreurs déjà rencontrées

| Symptôme | Cause | Solution |
|---|---|---|
| `NameError: name 'SELECT' is not defined` | SQL collé directement dans Python | Entourer de `con.sql(""" ... """)` |
| `No files found that match the pattern` | Fichier absent ou mauvais dossier | `pwd` puis `ls -lh data/raw/` |
| `Could not convert string ... to 'BIGINT'` | Inférence automatique des types | Lire en `all_varchar=true` |
| `ImportError: cannot import name ...` | Fichier non enregistré ou incomplet | Réécrire le fichier entier, vérifier avec `grep -n "def "` |
| `Must be specified` / `does not have permission` | Valeur d'exemple non remplacée ou mauvais ID de projet | `gcloud projects list` pour l'ID exact |
| `Invalid field name "_file_date"` | Préfixe `_FILE_` réservé par BigQuery | Colonne renommée `_source_date` |
| `Cannot query ... without a filter over column(s) '_source_date'` | Comportement voulu (garde-fou) | Ajouter `WHERE _source_date = "AAAA-MM-JJ"` |
| `can only be modified once in 1 hours` | Deux réglages du dataset trop rapprochés | Attendre une heure et relancer |
