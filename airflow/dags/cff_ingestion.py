"""Ingestion quotidienne des Ist-Daten CFF.

Lance backfill.py, qui compare les jours disponibles sur le portail
avec ceux déjà présents dans BigQuery et ne charge que les manquants.
Un lancement manqué (PC éteint) est donc rattrapé au suivant.
"""
from datetime import timedelta

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

with DAG(
    dag_id="cff_ingestion_quotidienne",
    description="Charge dans BigQuery les jours Ist-Daten manquants",
    schedule="0 8 * * *",
    start_date=pendulum.datetime(2026, 10, 1, tz="Europe/Zurich"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=15)},
    dagrun_timeout=timedelta(hours=2),
    tags=["cff", "ingestion"],
) as dag:
    BashOperator(
        task_id="load_missing_days",
        bash_command="python -u ingestion/backfill.py",
        cwd="/opt/airflow",
    )
