import sys
from datetime import date
from pathlib import Path

import duckdb
from google.cloud import bigquery, storage

from download_istdaten import download
from to_parquet import to_parquet

PROJECT = "cff-ponctualite"
BUCKET = "cff-ponctualite-raw"
TABLE = f"{PROJECT}.cff_raw.istdaten"
LOCATION = "europe-west6"


def upload(local: Path, day: str) -> str:
    blob_name = f"istdaten/source_date={day}/{local.name}"
    storage.Client(project=PROJECT).bucket(BUCKET).blob(blob_name).upload_from_filename(str(local))
    return f"gs://{BUCKET}/{blob_name}"


def load(uri: str, day: str) -> int:
    client = bigquery.Client(project=PROJECT, location=LOCATION)
    config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # remplace la partition
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY, field="_source_date"
        ),
    )
    partition = f"{TABLE}${day.replace('-', '')}"
    client.load_table_from_uri(uri, partition, job_config=config).result()
    rows = client.query(
        f"SELECT COUNT(*) AS n FROM `{TABLE}` WHERE _source_date = '{day}'"
    ).result()
    return next(iter(rows)).n


def run(day: str) -> None:
    date.fromisoformat(day)  # lève une erreur si la date est invalide
    csv = download(day)
    parquet = to_parquet(day)
    expected = duckdb.sql(f"SELECT COUNT(*) FROM read_parquet('{parquet}')").fetchone()[0]
    uri = upload(parquet, day)
    loaded = load(uri, day)
    if loaded != expected:
        raise RuntimeError(f"{day} : {loaded} lignes dans BigQuery, {expected} attendues")
    csv.unlink()
    print(f"{day} OK : {loaded} lignes chargées, CSV local supprimé")


if __name__ == "__main__":
    for day in sys.argv[1:]:
        run(day)
