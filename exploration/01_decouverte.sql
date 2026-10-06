-- =====================================================================
-- Projet CFF Ponctualité : exploration des Ist-Daten (DuckDB)
-- Fichier : exploration/01_decouverte.sql
-- Source  : jeu "ist-daten-v2" (opendata.swiss), fichier du 2026-10-04
-- =====================================================================


-- ---------------------------------------------------------------------
-- ÉTAPE 1 : Découverte du fichier brut (lecture directe du CSV)
-- ---------------------------------------------------------------------

-- Colonnes et types devinés par DuckDB
DESCRIBE SELECT * FROM read_csv_auto('data/raw/2026-10-04_istdaten.csv');

-- Volume : 1 689 184 lignes (dimanche)
SELECT COUNT(*) FROM read_csv_auto('data/raw/2026-10-04_istdaten.csv');

-- Aperçu
SELECT * FROM read_csv_auto('data/raw/2026-10-04_istdaten.csv') LIMIT 5;

-- Format des heures prévues vs réelles
-- -> ANKUNFTSZEIT au format '04.10.2026 06:47' (sans secondes)
SELECT ANKUNFTSZEIT, AN_PROGNOSE, AN_PROGNOSE_STATUS
FROM read_csv_auto('data/raw/2026-10-04_istdaten.csv')
WHERE ANKUNFTSZEIT IS NOT NULL
LIMIT 5;

-- Répartition par type de transport
-- -> trains ('Zug') = ~10 % des lignes ; 'Bus' et 'BUS' coexistent
SELECT PRODUKT_ID, COUNT(*) AS n
FROM read_csv_auto('data/raw/2026-10-04_istdaten.csv')
GROUP BY 1 ORDER BY n DESC;

-- Fiabilité des heures d'arrivée
-- -> REAL (mesurée) = 88 % ; GESCHAETZT, PROGNOSE, UNBEKANNT, NULL
SELECT AN_PROGNOSE_STATUS, COUNT(*) AS n
FROM read_csv_auto('data/raw/2026-10-04_istdaten.csv')
GROUP BY 1 ORDER BY n DESC;


-- ---------------------------------------------------------------------
-- ÉTAPE 2a : Couche brute (tout en VARCHAR)
-- L'inférence de type a cassé à la ligne 76 905 :
-- LINIEN_ID deviné en BIGINT, puis valeur '85:138:2332'
-- ---------------------------------------------------------------------

CREATE OR REPLACE TABLE ist_raw AS
SELECT *
FROM read_csv('data/raw/2026-10-04_istdaten.csv',
              delim = ';', header = true, all_varchar = true);

SELECT COUNT(*) FROM ist_raw;   -- attendu : 1689184


-- ---------------------------------------------------------------------
-- ÉTAPE 2b : Couche staging (renommage en anglais, typage explicite,
--            traduction des valeurs)
-- La couche brute garde les noms allemands d'origine (fidélité à la source).
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW ist AS
SELECT
    strptime(BETRIEBSTAG, '%d.%m.%Y')::DATE          AS operating_date,
    FAHRT_BEZEICHNER                                  AS trip_id,
    BETREIBER_ID                                      AS operator_id,
    BETREIBER_ABK                                     AS operator_code,
    BETREIBER_NAME                                    AS operator_name,
    CASE UPPER(PRODUKT_ID)
        WHEN 'ZUG'         THEN 'TRAIN'
        WHEN 'BUS'         THEN 'BUS'
        WHEN 'TRAM'        THEN 'TRAM'
        WHEN 'METRO'       THEN 'METRO'
        WHEN 'ZAHNRADBAHN' THEN 'RACK_RAILWAY'
        WHEN 'SCHIFF'      THEN 'BOAT'
        ELSE UPPER(PRODUKT_ID)          -- valeur inconnue : gardée visible
    END                                               AS transport_type,
    LINIEN_ID                                         AS line_id,
    LINIEN_TEXT                                       AS line_name,
    UMLAUF_ID                                         AS vehicle_circulation_id,
    VERKEHRSMITTEL_TEXT                               AS service_category,
    ZUSATZFAHRT_TF::BOOLEAN                           AS is_additional_trip,
    FAELLT_AUS_TF::BOOLEAN                            AS is_cancelled,
    BPUIC                                             AS stop_id,
    SLOID                                             AS stop_sloid,
    HALTESTELLEN_NAME                                 AS stop_name,
    try_strptime(ANKUNFTSZEIT, '%d.%m.%Y %H:%M')      AS arrival_scheduled,
    try_strptime(AN_PROGNOSE,  '%d.%m.%Y %H:%M:%S')   AS arrival_actual,
    CASE AN_PROGNOSE_STATUS
        WHEN 'REAL'       THEN 'MEASURED'
        WHEN 'GESCHAETZT' THEN 'ESTIMATED'
        WHEN 'PROGNOSE'   THEN 'FORECAST'
        WHEN 'UNBEKANNT'  THEN 'UNKNOWN'
        ELSE AN_PROGNOSE_STATUS
    END                                               AS arrival_status,
    try_strptime(ABFAHRTSZEIT, '%d.%m.%Y %H:%M')      AS departure_scheduled,
    try_strptime(AB_PROGNOSE,  '%d.%m.%Y %H:%M:%S')   AS departure_actual,
    CASE AB_PROGNOSE_STATUS
        WHEN 'REAL'       THEN 'MEASURED'
        WHEN 'GESCHAETZT' THEN 'ESTIMATED'
        WHEN 'PROGNOSE'   THEN 'FORECAST'
        WHEN 'UNBEKANNT'  THEN 'UNKNOWN'
        ELSE AB_PROGNOSE_STATUS
    END                                               AS departure_status,
    DURCHFAHRT_TF::BOOLEAN                            AS is_pass_through
FROM ist_raw;


-- ---------------------------------------------------------------------
-- ÉTAPE 2c : Test qualité — aucune date perdue par try_strptime
-- Attendu : 0 partout
-- ---------------------------------------------------------------------

SELECT
    COUNT(*) FILTER (WHERE r.ANKUNFTSZEIT IS NOT NULL AND s.arrival_scheduled   IS NULL) AS fail_arrival_scheduled,
    COUNT(*) FILTER (WHERE r.AN_PROGNOSE  IS NOT NULL AND s.arrival_actual      IS NULL) AS fail_arrival_actual,
    COUNT(*) FILTER (WHERE r.ABFAHRTSZEIT IS NOT NULL AND s.departure_scheduled IS NULL) AS fail_departure_scheduled,
    COUNT(*) FILTER (WHERE r.AB_PROGNOSE  IS NOT NULL AND s.departure_actual    IS NULL) AS fail_departure_actual
FROM ist_raw r
POSITIONAL JOIN ist s;

-- Contrôle des valeurs traduites (aucun mot allemand ne doit rester)
SELECT transport_type, COUNT(*) AS n FROM ist GROUP BY 1 ORDER BY n DESC;
SELECT arrival_status, COUNT(*) AS n FROM ist GROUP BY 1 ORDER BY n DESC;


-- ---------------------------------------------------------------------
-- ÉTAPE 2d : Calcul du retard à l'arrivée (trains, heures mesurées)
-- ---------------------------------------------------------------------

SELECT
    stop_name,
    line_name,
    arrival_scheduled,
    arrival_actual,
    date_diff('second', arrival_scheduled, arrival_actual) / 60.0 AS delay_min
FROM ist
WHERE transport_type = 'TRAIN'
  AND arrival_status = 'MEASURED'
  AND NOT is_cancelled
LIMIT 10;


-- ---------------------------------------------------------------------
-- ÉTAPE 2e : Ponctualité des grandes gares romandes
-- Ponctuel = retard < 3 minutes (180 s)
-- ---------------------------------------------------------------------

SELECT
    stop_name,
    COUNT(*) AS arrivals,
    ROUND(AVG(date_diff('second', arrival_scheduled, arrival_actual)) / 60.0, 2)               AS avg_delay_min,
    ROUND(100.0 * AVG((date_diff('second', arrival_scheduled, arrival_actual) < 180)::INT), 1) AS pct_on_time
FROM ist
WHERE transport_type = 'TRAIN'
  AND arrival_status = 'MEASURED'
  AND NOT is_cancelled
  AND stop_name IN ('Genève', 'Lausanne', 'Genève-Aéroport',
                    'Fribourg/Freiburg', 'Neuchâtel')
GROUP BY 1
ORDER BY arrivals DESC;


-- ---------------------------------------------------------------------
-- Utilitaire : retrouver les noms exacts des gares
-- ---------------------------------------------------------------------

SELECT stop_name, COUNT(*) AS n
FROM ist
WHERE transport_type = 'TRAIN'
  AND (stop_name ILIKE '%gen%ve%'
    OR stop_name ILIKE '%lausanne%'
    OR stop_name ILIKE '%fribourg%'
    OR stop_name ILIKE '%neuch%')
GROUP BY 1
ORDER BY n DESC
LIMIT 15;
