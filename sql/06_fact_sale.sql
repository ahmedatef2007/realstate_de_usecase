/* =========================================================
   06_fact_sale.sql
   - Create & populate fact_sale
   ========================================================= */

USE realestate_dwh;

DROP TABLE IF EXISTS fact_sale;

CREATE TABLE fact_sale (
    sale_id                 BIGINT PRIMARY KEY,
    lead_id                 BIGINT,          -- join back to fact_lead

    -- dimension keys
    property_type_key       INT,
    sale_category_key       INT,
    area_key                INT,
    compound_key            INT,
    reservation_date_key    INT,
    contract_date_key       INT,

    -- measures / attributes
    unit_value              DECIMAL(18,2),
    expected_value          DECIMAL(18,2),
    actual_value            DECIMAL(18,2),
    years_of_payment        DECIMAL(10,2),
    unit_location           VARCHAR(255)
);

ALTER TABLE fact_sale
    ADD CONSTRAINT fk_fact_sale_lead
        FOREIGN KEY (lead_id)
        REFERENCES fact_lead(lead_id),

    ADD CONSTRAINT fk_fact_sale_property_type
        FOREIGN KEY (property_type_key)
        REFERENCES dim_property_type(property_type_key),

    ADD CONSTRAINT fk_fact_sale_sale_category
        FOREIGN KEY (sale_category_key)
        REFERENCES dim_sale_category(sale_category_key),

    ADD CONSTRAINT fk_fact_sale_area
        FOREIGN KEY (area_key)
        REFERENCES dim_area(area_key),

    ADD CONSTRAINT fk_fact_sale_compound
        FOREIGN KEY (compound_key)
        REFERENCES dim_compound(compound_key),

    ADD CONSTRAINT fk_fact_sale_reservation_date
        FOREIGN KEY (reservation_date_key)
        REFERENCES dim_date(date_key),

    ADD CONSTRAINT fk_fact_sale_contract_date
        FOREIGN KEY (contract_date_key)
        REFERENCES dim_date(date_key);

TRUNCATE TABLE fact_sale;

INSERT INTO fact_sale (
    sale_id,
    lead_id,
    property_type_key,
    sale_category_key,
    area_key,
    compound_key,
    reservation_date_key,
    contract_date_key,
    unit_value,
    expected_value,
    actual_value,
    years_of_payment,
    unit_location
)
SELECT
    s.sale_id,
    fl.lead_id,

    dpt.property_type_key,
    dsc.sale_category_key,
    dar.area_key,
    dco.compound_key,

    dd_res.date_key   AS reservation_date_key,
    dd_con.date_key   AS contract_date_key,

    s.unit_value,
    s.expected_value,
    s.actual_value,
    s.years_of_payment,
    s.unit_location
FROM realestate_stg.stg_sales s
LEFT JOIN dim_property_type   dpt  ON dpt.property_type_id   = s.property_type_id
LEFT JOIN dim_sale_category   dsc  ON dsc.raw_sale_category  = s.sale_category
LEFT JOIN dim_area            dar  ON dar.area_id            = s.area_id
LEFT JOIN dim_compound        dco  ON dco.compound_id        = s.compound_id
LEFT JOIN fact_lead           fl   ON fl.lead_id             = s.lead_id
LEFT JOIN dim_date            dd_res
       ON dd_res.full_date = DATE(s.date_of_reservation)
LEFT JOIN dim_date            dd_con
       ON dd_con.full_date = DATE(s.date_of_contraction);
