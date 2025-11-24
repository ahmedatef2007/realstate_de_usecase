

-- optional sanity check
SELECT *
FROM dim_date
WHERE full_date LIKE '%-02-29'
ORDER BY full_date;



/* =========================================================
   9) BASIC STAGING SANITY CHECKS
   ========================================================= */

SELECT 
    COUNT(*)               AS total_rows,
    COUNT(DISTINCT lead_id) AS distinct_leads
FROM realestate_dwh.stg_leads;

SELECT 
    lead_id,
    COUNT(*) AS cnt
FROM realestate_dwh.stg_leads
GROUP BY lead_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;



/* =========================================================
   12) SANITY CHECKS ON FACT_LEAD
   ========================================================= */

SELECT
  COUNT(*)                               AS total_rows,
  SUM(customer_key       IS NULL)        AS missing_customer,
  SUM(agent_key          IS NULL)        AS missing_agent,
  SUM(lead_status_key    IS NULL)        AS missing_lead_status,
  SUM(lead_type_key      IS NULL)        AS missing_lead_type,
  SUM(contact_method_key IS NULL)        AS missing_contact_method,
  SUM(lead_source_key    IS NULL)        AS missing_lead_source,
  SUM(campaign_key       IS NULL)        AS missing_campaign,
  SUM(area_key           IS NULL)        AS missing_area,
  SUM(compound_key       IS NULL)       AS missing_compound,
  SUM(developer_key      IS NULL)        AS missing_developer
FROM fact_lead;

SELECT COUNT(*)  -- 53851
FROM realestate_dwh.stg_leads
WHERE area_id IS NULL;

-- confirm no duplicate lead_id in final selection
SELECT
    lead_id,
    COUNT(*) AS cnt
FROM (
    SELECT
        sl.lead_id,
        ROW_NUMBER() OVER (
            PARTITION BY sl.lead_id
            ORDER BY COALESCE(sl.updated_at, sl.created_at) DESC
        ) AS rn
    FROM realestate_dwh.stg_leads sl
) x
WHERE rn = 1
GROUP BY lead_id
HAVING COUNT(*) > 1;
/* =========================================================
   13) KPIs / ANALYTICS QUERIES (LEADS FUNNEL)
   ========================================================= */

-- Funnel distribution
SELECT 
    dls.funnel_stage,
    COUNT(*) AS leads_count
FROM fact_lead f
JOIN dim_lead_status dls ON dls.lead_status_key = f.lead_status_key
GROUP BY dls.funnel_stage
ORDER BY leads_count DESC;

-- Funnel counts by stage
SELECT
    SUM(dls.funnel_stage = 'TO_CONTACT')      AS to_contact,
    SUM(dls.funnel_stage = 'CONTACT_ATTEMPT') AS contacted,
    SUM(dls.funnel_stage = 'MEETING_BOOKED')  AS meeting_booked,
    SUM(dls.funnel_stage = 'MEETING_HELD')    AS meeting_held,
    SUM(dls.funnel_stage = 'RESERVATION')     AS reservation,
    SUM(dls.funnel_stage = 'CONTRACT')        AS contract_stage,
    SUM(dls.funnel_stage = 'WON')             AS sales
FROM fact_lead f
JOIN dim_lead_status dls ON dls.lead_status_key = f.lead_status_key;

-- Conversion rates
SELECT
    ROUND(SUM(dls.funnel_stage = 'WON')         / COUNT(*) * 100, 2) AS final_conversion_rate_pct,
    ROUND(SUM(dls.funnel_stage = 'MEETING_HELD') / COUNT(*) * 100, 2) AS meeting_conversion_pct,
    ROUND(SUM(dls.funnel_stage = 'RESERVATION')  / COUNT(*) * 100, 2) AS reservation_conversion_pct
FROM fact_lead f
JOIN dim_lead_status dls ON dls.lead_status_key = f.lead_status_key;

-- Agent performance
SELECT
    da.user_id,
    COUNT(*) AS total_leads,
    SUM(dls.is_won) AS sales,
    SUM(dls.funnel_stage = 'MEETING_HELD') AS meetings,
    ROUND(SUM(dls.is_won) / COUNT(*) * 100, 2) AS win_rate_pct
FROM fact_lead f
JOIN dim_agent da       ON da.agent_key       = f.agent_key
JOIN dim_lead_status dls ON dls.lead_status_key = f.lead_status_key
GROUP BY da.user_id
ORDER BY win_rate_pct DESC;

-- Lead source performance
SELECT
    dlsrc.lead_source_clean AS lead_source,
    dlsrc.source_group,
    COUNT(*) AS total_leads,
    SUM(dls.is_won) AS sales,
    ROUND(SUM(dls.is_won) / COUNT(*) * 100, 2) AS win_rate_pct
FROM fact_lead f
JOIN dim_lead_source dlsrc ON dlsrc.lead_source_key = f.lead_source_key
JOIN dim_lead_status dls   ON dls.lead_status_key   = f.lead_status_key
GROUP BY dlsrc.lead_source_clean, dlsrc.source_group
ORDER BY sales DESC;

-- Buyer / seller / commercial mix
SELECT
    SUM(is_buyer)      AS buyer_leads,
    SUM(is_seller)     AS seller_leads,
    SUM(is_commercial) AS commercial_leads
FROM fact_lead;
-- 3) Funnel by month (sanity: does it grow over time?)
SELECT
    dd.year,
    dd.month,
    dls.funnel_stage,
    COUNT(*) AS leads_count
FROM fact_lead f
JOIN dim_date dd       ON dd.date_key = f.created_date_key
JOIN dim_lead_status dls ON dls.lead_status_key = f.lead_status_key
GROUP BY dd.year, dd.month, dls.funnel_stage
ORDER BY dd.year, dd.month, leads_count DESC;


SELECT 
    agent.user_id as agent,
    COUNT(DISTINCT fl.lead_id) AS total_leads,
    COUNT(DISTINCT fs.sale_id) AS total_sales,
    ROUND(COUNT(fs.sale_id) / COUNT(fl.lead_id) * 100, 2) AS lead_to_sale_pct
FROM fact_lead fl
LEFT JOIN fact_sale fs ON fs.lead_id = fl.lead_id
JOIN dim_agent agent ON agent.agent_key = fl.agent_key
GROUP BY agent.user_id;



SELECT 
    agent.user_id as agent,
    COUNT(DISTINCT fl.lead_id) AS total_leads,
    COUNT(DISTINCT fs.sale_id) AS total_sales,
    ROUND(COUNT(fs.sale_id) / COUNT(fl.lead_id) * 100, 2) AS lead_to_sale_pct
FROM fact_lead fl
LEFT JOIN fact_sale fs ON fs.lead_id = fl.lead_id
JOIN dim_agent agent ON agent.agent_key = fl.agent_key
GROUP BY agent.user_id;

SELECT
    COUNT(*)                                                AS total_sales,
    SUM(fl.lead_id IS NOT NULL)                            AS sales_with_lead,
    SUM(fl.lead_id IS NULL)                                AS sales_without_lead,
    ROUND(SUM(fl.lead_id IS NOT NULL) / COUNT(*) * 100, 2) AS pct_with_lead
FROM realestate_dwh.fact_sale fs
LEFT JOIN realestate_dwh.fact_lead fl
       ON fl.lead_id = fs.lead_id;
# total_sales, sales_with_lead, sales_without_lead, pct_with_lead
-- '1567', '1567', '0', '100.00'
SELECT
    COUNT(*)                 AS total_sales,
    SUM(actual_value)        AS total_actual_value,
    AVG(actual_value)        AS avg_actual_value,
    SUM(expected_value)      AS total_expected_value,
    AVG(expected_value)      AS avg_expected_value,
    SUM(unit_value)          AS total_unit_value,
    AVG(unit_value)          AS avg_unit_value,
    AVG(years_of_payment)    AS avg_years_of_payment
FROM realestate_dwh.fact_sale;


SELECT
    dpt.property_type_group,
    dpt.property_type_name,
    COUNT(*)                      AS sales_count,
    SUM(fs.actual_value)          AS total_actual_value,
    AVG(fs.actual_value)          AS avg_actual_value,
    AVG(fs.years_of_payment)      AS avg_years_of_payment
FROM realestate_dwh.fact_sale fs
JOIN realestate_dwh.dim_property_type dpt
      ON dpt.property_type_key = fs.property_type_key
GROUP BY
    dpt.property_type_group,
    dpt.property_type_name
ORDER BY total_actual_value DESC;


SELECT
    dsc.sale_category_group,
    dsc.sale_category_clean,
    COUNT(*)                 AS sales_count,
    SUM(fs.actual_value)     AS total_actual_value,
    AVG(fs.actual_value)     AS avg_actual_value
FROM realestate_dwh.fact_sale fs
JOIN realestate_dwh.dim_sale_category dsc
      ON dsc.sale_category_key = fs.sale_category_key
GROUP BY
    dsc.sale_category_group,
    dsc.sale_category_clean
ORDER BY total_actual_value DESC;




