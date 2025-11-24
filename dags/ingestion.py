# dags/ingestion.py

import pandas as pd
from airflow.providers.mysql.hooks.mysql import MySqlHook


EXCEL_PATH = "/opt/airflow/data/Case_Study_Data___Data_Engineering__1___2_.xlsx"
# ^ for Docker. If you’re on venv, use your normal path, e.g. r"C:\...\data\..."

def run_ingestion():
    """
    Reads Excel sheets and loads them into realestate_source.de_leads_raw
    and realestate_source.de_sales_raw.
    """
    # Use Airflow connection instead of hardcoded URI
    hook = MySqlHook(mysql_conn_id="mysql_source")  # you will create this conn in UI
    engine = hook.get_sqlalchemy_engine()

    # Read Excel sheets (same sheet names as your original script)
    leads_df = pd.read_excel(EXCEL_PATH, sheet_name="DE LEADS")
    sales_df = pd.read_excel(EXCEL_PATH, sheet_name="DE SALES")

    # Load into MySQL schema realestate_source
    leads_df.to_sql("de_leads_raw", engine, schema="realestate_source",
                    if_exists="replace", index=False)
    sales_df.to_sql("de_sales_raw", engine, schema="realestate_source",
                    if_exists="replace", index=False)

    # Optional: simple completeness check like your printouts
    with engine.connect() as conn:
        src_leads_count = len(leads_df)
        src_sales_count = len(sales_df)

        db_leads_count = conn.execute("SELECT COUNT(*) FROM realestate_source.de_leads_raw").scalar()
        db_sales_count = conn.execute("SELECT COUNT(*) FROM realestate_source.de_sales_raw").scalar()

        print(f"Leads rows - source: {src_leads_count}, db: {db_leads_count}")
        print(f"Sales rows - source: {src_sales_count}, db: {db_sales_count}")
