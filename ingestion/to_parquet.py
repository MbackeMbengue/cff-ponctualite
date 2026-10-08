import sys
import duckdb
from pathlib import Path

def to_parquet(day: str, raw_dir: str = "data/raw", out_dir: str = "data/parquet/istdaten") -> Path:
    src = Path(raw_dir) / f"{day}_istdaten.csv"
    dst = Path(out_dir) / f"file_date={day}" / f"{day}_istdaten.parquet"
    dst.parent.mkdir(parents=True, exist_ok=True)
    duckdb.sql(f"""
        COPY (
            SELECT *,
                   DATE '{day}'      AS _file_date,
                   current_timestamp AS _ingested_at
            FROM read_csv('{src}', delim=';', header=true, all_varchar=true)
        ) TO '{dst}' (FORMAT PARQUET, COMPRESSION ZSTD)
    """)
    print(f"{dst} : {src.stat().st_size / 1e6:.0f} Mo (CSV) -> {dst.stat().st_size / 1e6:.0f} Mo (Parquet)")
    return dst

if __name__ == "__main__":
    to_parquet(sys.argv[1])
