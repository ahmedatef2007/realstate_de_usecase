import pandas as pd
import sqlalchemy

engine = sqlalchemy.create_engine(
    "mysql+pymysql://root:root@localhost:3306/realestate_source"
)

file_path = "data/Case_Study_Data___Data_Engineering__1___2_.xlsx"

leads_df = pd.read_excel(file_path, sheet_name="DE LEADS")
sales_df = pd.read_excel(file_path, sheet_name="DE SALES")

leads_df.to_sql("de_leads_raw", engine, if_exists="replace", index=False)
sales_df.to_sql("de_sales_raw", engine, if_exists="replace", index=False)

# ---- COMPLETENESS CHECKS ----

# 1) Row counts source vs target
src_leads_count = len(leads_df)
src_sales_count = len(sales_df)

db_leads_count = pd.read_sql("SELECT COUNT(*) AS cnt FROM de_leads_raw", engine)["cnt"][0]
db_sales_count = pd.read_sql("SELECT COUNT(*) AS cnt FROM de_sales_raw", engine)["cnt"][0]

print(f"Leads rows - source: {src_leads_count}, db: {db_leads_count}")
print(f"Sales rows - source: {src_sales_count}, db: {db_sales_count}")
