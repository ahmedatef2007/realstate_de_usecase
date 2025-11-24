# Real Estate Lead & Sales DWH (Nawy Use Case)

End-to-end data engineering use case for a real estate company (similar to Nawy):
- Ingest raw CRM exports (Leads & Sales) into MySQL
- Build a dimensional data warehouse (Leads & Sales star schema)
- Orchestrate the pipeline using Apache Airflow
- Expose funnel & performance KPIs via SQL

---

## 🔧 Tech Stack

- **Database**: MySQL
- **Orchestration**: Apache Airflow
- **Scripting**: Python
- **Modeling**: Kimball-style star schema (Fact + Dimensions)

---

## 🧱 High-Level Architecture

1. **Source Layer**
   - Raw files (Excel/CSV) from CRM/real-estate system
   - Loaded into `realestate_source` schema:
     - `de_leads_raw`
     - `de_sales_raw`

2. **Staging Layer (`realestate_stg`)**
   - Cleaned & standardized copies of raw tables:
     - `stg_leads`
     - `stg_sales`

3. **DWH Layer (`realestate_dwh`)**
   - Dimensions for:
     - Lead funnel, lead type, contact method, lead source, campaigns
     - Date, customer, agent, area, compound, developer
     - Property type, sale category
   - Facts:
     - `fact_lead` – full lead lifecycle with funnel status & attributes
     - `fact_sale` – sales tied back to leads

4. **Orchestration**
   - Airflow DAG:
     - Runs ingestion
     - Executes SQL scripts in order
     - Rebuilds DWH tables (current version is full refresh)

---

## 📂 Repository Structure

```bash
.
├─ README.md
├─ .gitignore
├─ requirements.txt
├─ Nawy_DE_Usecase_Documentation.pdf
├─ sql/
│  ├─ 01_staging.sql          # create stg_leads / stg_sales from raw
│  ├─ 02_lead_dims.sql        # lead-related dimensions (status, type, contact, source, campaign)
│  ├─ 03_core_dims.sql        # core dims (date, customer, agent, area, compound, developer)
│  ├─ 04_sales_dims.sql       # sales-specific dims (property type, sale category)
│  ├─ 05_fact_lead.sql        # fact_lead (latest lead per id)
│  └─ 06_fact_sale.sql        # fact_sale (joined to fact_lead + dims)
├─ dags/
│  └─ realestate_dag.py       # Airflow DAG wiring the whole pipeline
└─ scripts/
   └─ ingestion.py            # Python script ingesting raw files into MySQL
