from datetime import datetime
from pathlib import Path

from airflow import DAG
from airflow.operators.python import PythonOperator
import sqlalchemy
from sqlalchemy import text

import openpyxl  # Ensure openpyxl is available for Excel reading

# Use same connection as your ingestion script
ENGINE_URL = "mysql+pymysql://root:root@host.docker.internal:3306/realestate_source"
engine = sqlalchemy.create_engine(ENGINE_URL)


def run_sql_file(sql_path: str):
    """Execute a .sql file against MySQL, statement by statement."""
    full_path = Path(sql_path)
    raw_sql = full_path.read_text()

    statements = [s.strip() for s in raw_sql.split(';') if s.strip()]

    engine = sqlalchemy.create_engine(ENGINE_URL)

    with engine.begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt))


def run_ingestion():
    import pandas as pd

    engine = sqlalchemy.create_engine(ENGINE_URL)

    file_path = "/opt/airflow/data/Case_Study_Data___Data_Engineering__1___2_.xlsx"

    df_leads = pd.read_excel(file_path, sheet_name="DE LEADS")
    df_sales = pd.read_excel(file_path, sheet_name="DE SALES")

    df_leads.to_sql("de_leads_raw", engine, schema="realestate_source", if_exists="replace", index=False)
    df_sales.to_sql("de_sales_raw", engine, schema="realestate_source", if_exists="replace", index=False)


with DAG(
    dag_id="realestate_pipeline",
    start_date=datetime(2025, 1, 1),
    schedule="@daily",  # run once per day
    catchup=False,
    tags=["realestate"],
) as dag:
    ingest = PythonOperator(
        task_id="ingest_excel",
        python_callable=run_ingestion,
    )

    stg = PythonOperator(
        task_id="build_staging",
        python_callable=run_sql_file,
        op_args=["/opt/airflow/sql/01_staging.sql"],
    )

    lead_dims = PythonOperator(
        task_id="build_lead_dims",
        python_callable=run_sql_file,
        op_args=["/opt/airflow/sql/02_lead_dims.sql"],
    )

    core_dims = PythonOperator(
        task_id="build_core_dims",
        python_callable=run_sql_file,
        op_args=["/opt/airflow/sql/03_core_dims.sql"],
    )

    sales_dims = PythonOperator(
        task_id="build_sales_dims",
        python_callable=run_sql_file,
        op_args=["/opt/airflow/sql/04_sales_dims.sql"],
    )

    fact_lead = PythonOperator(
        task_id="build_fact_lead",
        python_callable=run_sql_file,
        op_args=["/opt/airflow/sql/05_fact_lead.sql"],
    )

    fact_sale = PythonOperator(
        task_id="build_fact_sale",
        python_callable=run_sql_file,
        op_args=["/opt/airflow/sql/06_fact_sale.sql"],
    )

    ingest >> stg >> lead_dims >> core_dims >> sales_dims >> fact_lead >> fact_sale
