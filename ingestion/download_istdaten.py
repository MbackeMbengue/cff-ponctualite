import sys, requests
from pathlib import Path

API = "https://ckan.opendata.swiss/api/3/action/package_show"
DATASET = "ist-daten-v2"

def list_resources() -> list[dict]:
    resp = requests.get(API, params={"id": DATASET}, timeout=30)
    resp.raise_for_status()
    return resp.json()["result"]["resources"]

def find_url(day: str) -> str:
    for r in list_resources():
        if r["url"].lower().endswith(f"{day}_istdaten.csv"):
            return r["url"]
    raise ValueError(f"Aucun fichier trouvé pour {day}")

def download(day: str, out_dir: str = "data/raw") -> Path:
    path = Path(out_dir) / f"{day}_istdaten.csv"
    if path.exists():
        print(f"Déjà présent : {path}"); return path
    with requests.get(find_url(day), stream=True, timeout=120) as r:
        r.raise_for_status()
        with open(path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 20):
                f.write(chunk)
    print(f"Téléchargé : {path}"); return path

if __name__ == "__main__":
    download(sys.argv[1])
