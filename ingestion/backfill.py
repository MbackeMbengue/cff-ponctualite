import sys
from google.cloud import bigquery

from download_istdaten import list_resources
from pipeline import run, PROJECT, LOCATION


def available_days() -> list[str]:
    names = [r["url"].rsplit("/", 1)[-1] for r in list_resources()]
    return sorted(n.split("_")[0] for n in names if n.endswith("_istdaten.csv"))


def loaded_days() -> set[str]:
    client = bigquery.Client(project=PROJECT, location=LOCATION)
    rows = client.query(f"""
        SELECT partition_id
        FROM `{PROJECT}.cff_raw.INFORMATION_SCHEMA.PARTITIONS`
        WHERE table_name = 'istdaten'
          AND partition_id NOT IN ('__NULL__', '__UNPARTITIONED__')
    """).result()
    return {f"{p[:4]}-{p[4:6]}-{p[6:]}" for p in (r.partition_id for r in rows)}


if __name__ == "__main__":
    done = loaded_days()
    todo = [d for d in available_days() if d not in done]
    print(f"Déjà chargés : {len(done)} | À charger : {len(todo)}")
    if todo:
        print(f"Du {todo[0]} au {todo[-1]}")
    if "--dry-run" in sys.argv:
        sys.exit(0)

    failed = []
    for day in todo:          # du plus ancien au plus récent
        try:
            run(day)
        except Exception as e:
            print(f"{day} ÉCHEC : {e}")
            failed.append(day)
    print(f"Terminé : {len(todo) - len(failed)} OK, {len(failed)} échec(s) {failed}")
    sys.exit(1 if failed else 0)
