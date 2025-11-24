/* =========================================================
   01_staging.sql
   - Create staging DB and raw-like staging tables
   ========================================================= */

CREATE DATABASE IF NOT EXISTS realestate_stg;
-- USE realestate_stg;

-- =========================
-- 1) Leads staging
-- =========================
DROP TABLE IF EXISTS stg_leads;

CREATE TABLE stg_leads AS
SELECT
    id                  AS lead_id,
    date_of_last_request,
    buyer,
    seller,
    best_time_to_call,
    budget,
    created_at,
    updated_at,
    user_id,
    location,
    date_of_last_contact,
    status_name,
    commercial,
    merged,
    area_id,
    compound_id,
    developer_id,
    meeting_flag,
    do_not_call,
    lead_type_id,
    customer_id,
    method_of_contact,
    lead_source,
    campaign,
    lead_type
FROM realestate_source.de_leads_raw;

-- =========================
-- 2) Sales staging
-- =========================
DROP TABLE IF EXISTS stg_sales;

CREATE TABLE stg_sales AS
SELECT
    id                  AS sale_id,
    lead_id,
    unit_value,
    unit_location,
    expected_value,
    actual_value,
    date_of_reservation,
    reservation_update_date,
    date_of_contraction,
    property_type_id,
    area_id,
    compound_id,
    sale_category,
    years_of_payment,
    property_type
FROM realestate_source.de_sales_raw;
