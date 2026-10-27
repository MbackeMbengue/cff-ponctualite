# Décisions de conception

1. **Source** : jeu ist-daten-v2 via l'API CKAN d'opendata.swiss, fenêtre glissante de 50 jours.

2. **Couche brute** : tout en VARCHAR, car l'inférence de schéma cassait à la ligne 76 905 sur LINIEN_ID.

3. **Normalisation** de PRODUKT_ID (Bus / BUS).

4. **Retard** calculé uniquement sur les heures REAL (88 % des arrivées).

5. **Ponctualité** : retard de moins de 3 minutes ; retard brut conservé, retard_positif utilisé pour les moyennes.

6. **Filtrage** sur les identifiants (BPUIC), pas sur les noms de gares.

7. **Langues** : renommage des colonnes et traduction des valeurs en anglais dans la couche staging ; la couche brute conserve les noms allemands d'origine.

8. **Colonnes techniques** : ajoutées en couche brute et préfixées par _ (_source_date, _ingested_at). Le nom _file_date a été abandonné : BigQuery réserve le préfixe _FILE_

9. **Chargement par partition** (table$AAAAMMJJ + --replace) : relancer un jour le remplace sans doublon.

10. **Format de stockage** : Parquet compressé en ZSTD, avec chemins de partition de type Hive (source_date=AAAA-MM-JJ/). Résultat : 429 Mo → 18 Mo (×24).

11. **Garde-fou de coûts** : filtre de partition obligatoire sur _source_date ; toute requête sans filtre de date est refusée.

12. **Infrastructure** : projet GCP dédié, bucket et dataset en europe-west6 (Zurich), alerte budget de 5 €.

13. **Facturation du stockage** : modèle physique (compressé) sur le dataset cff_raw ; compression mesurée de 10,7 (490 Mo logiques → 46 Mo physiques par jour). Time travel réduit à 48 h, la couche brute étant rechargeable depuis GCS.

14. **Orchestration** : Airflow 3.3.2 en local avec Docker Compose, en LocalExecutor plutôt que CeleryExecutor (une seule machine, environ 1 Go de mémoire économisé). Cloud Composer écarté pour son coût.

15. **DAG auto-réparateur** : la tâche quotidienne lance backfill.py, qui charge tous les jours manquants. Un lancement manqué (PC éteint) est rattrapé au suivant, sans logique de dates dans Airflow (catchup=False, max_active_runs=1).

16. **Isolation** : projet Docker Compose nommé cff-airflow, pour ne pas entrer en collision avec un autre Airflow local.
