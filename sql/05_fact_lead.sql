/* =========================================================
   05_fact_lead.sql
   - Create & populate fact_lead
   ========================================================= */

USE realestate_dwh;

DROP TABLE IF EXISTS fact_lead;

CREATE TABLE fact_lead (
    lead_id                 BIGINT PRIMARY KEY,

    -- foreign keys to dimensions
    customer_key            INT,
    agent_key               INT,
    lead_status_key         INT,
    lead_type_key           INT,
    contact_method_key      INT,
    lead_source_key         INT,
    campaign_key            INT,
    area_key                INT,
    compound_key            INT,
    developer_key           INT,

    created_date_key        INT,
    last_request_date_key   INT,
    last_contact_date_key   INT,

    -- measures / attributes
    budget                  DECIMAL(18,2),
    is_buyer                TINYINT,
    is_seller               TINYINT,
    is_commercial           TINYINT,
    meeting_flag            TINYINT,
    do_not_call_flag        TINYINT,

    location                VARCHAR(255)
);

ALTER TABLE fact_lead
    ADD CONSTRAINT fk_fact_lead_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer(customer_key),

    ADD CONSTRAINT fk_fact_lead_agent
        FOREIGN KEY (agent_key)
        REFERENCES dim_agent(agent_key),

    ADD CONSTRAINT fk_fact_lead_status
        FOREIGN KEY (lead_status_key)
        REFERENCES dim_lead_status(lead_status_key),

    ADD CONSTRAINT fk_fact_lead_lead_type
        FOREIGN KEY (lead_type_key)
        REFERENCES dim_lead_type(lead_type_key),

    ADD CONSTRAINT fk_fact_lead_contact_method
        FOREIGN KEY (contact_method_key)
        REFERENCES dim_contact_method(contact_method_key),

    ADD CONSTRAINT fk_fact_lead_lead_source
        FOREIGN KEY (lead_source_key)
        REFERENCES dim_lead_source(lead_source_key),

    ADD CONSTRAINT fk_fact_lead_campaign
        FOREIGN KEY (campaign_key)
        REFERENCES dim_campaign(campaign_key),

    ADD CONSTRAINT fk_fact_lead_area
        FOREIGN KEY (area_key)
        REFERENCES dim_area(area_key),

    ADD CONSTRAINT fk_fact_lead_compound
        FOREIGN KEY (compound_key)
        REFERENCES dim_compound(compound_key),

    ADD CONSTRAINT fk_fact_lead_developer
        FOREIGN KEY (developer_key)
        REFERENCES dim_developer(developer_key),

    ADD CONSTRAINT fk_fact_lead_created_date
        FOREIGN KEY (created_date_key)
        REFERENCES dim_date(date_key),

    ADD CONSTRAINT fk_fact_lead_last_request_date
        FOREIGN KEY (last_request_date_key)
        REFERENCES dim_date(date_key),

    ADD CONSTRAINT fk_fact_lead_last_contact_date
        FOREIGN KEY (last_contact_date_key)
        REFERENCES dim_date(date_key);

TRUNCATE TABLE fact_lead;

INSERT INTO fact_lead (
    lead_id,
    customer_key,
    agent_key,
    lead_status_key,
    lead_type_key,
    contact_method_key,
    lead_source_key,
    campaign_key,
    area_key,
    compound_key,
    developer_key,
    created_date_key,
    last_request_date_key,
    last_contact_date_key,
    budget,
    is_buyer,
    is_seller,
    is_commercial,
    meeting_flag,
    do_not_call_flag,
    location
)
SELECT
    s.lead_id,
    dc.customer_key,
    da.agent_key,
    dls.lead_status_key,
    dlt.lead_type_key,
    dcm.contact_method_key,
    dlsrc.lead_source_key,
    dcamp.campaign_key,
    dar.area_key,
    dco.compound_key,
    ddv.developer_key,
    dd_created.date_key      AS created_date_key,
    dd_last_req.date_key     AS last_request_date_key,
    dd_last_contact.date_key AS last_contact_date_key,
    s.budget,
    CASE WHEN s.buyer      = 1 THEN 1 ELSE 0 END AS is_buyer,
    CASE WHEN s.seller     = 1 THEN 1 ELSE 0 END AS is_seller,
    CASE WHEN s.commercial = 1 THEN 1 ELSE 0 END AS is_commercial,
    COALESCE(s.meeting_flag, 0) AS meeting_flag,
    COALESCE(s.do_not_call, 0)  AS do_not_call_flag,
    s.location
FROM (
    -- latest version per lead_id
    SELECT
        sl.*,
        ROW_NUMBER() OVER (
            PARTITION BY sl.lead_id
            ORDER BY COALESCE(sl.updated_at, sl.created_at) DESC
        ) AS rn
    FROM realestate_stg.stg_leads sl
) s
LEFT JOIN dim_customer       dc    ON dc.customer_id         = s.customer_id
LEFT JOIN dim_agent          da    ON da.user_id             = s.user_id
LEFT JOIN dim_lead_status    dls   ON dls.raw_status_name    = s.status_name
LEFT JOIN dim_lead_type      dlt   ON dlt.lead_type_id       = s.lead_type_id
LEFT JOIN dim_contact_method dcm   ON dcm.raw_contact_method = TRIM(s.method_of_contact)
LEFT JOIN dim_lead_source    dlsrc ON dlsrc.raw_lead_source  = TRIM(s.lead_source)
LEFT JOIN dim_campaign       dcamp ON dcamp.raw_campaign     = TRIM(s.campaign)
LEFT JOIN dim_area           dar   ON dar.area_id            = s.area_id
LEFT JOIN dim_compound       dco   ON dco.compound_id        = s.compound_id
LEFT JOIN dim_developer      ddv   ON ddv.developer_id       = s.developer_id
LEFT JOIN dim_date           dd_created
       ON dd_created.full_date = DATE(s.created_at)
LEFT JOIN dim_date           dd_last_req
       ON dd_last_req.full_date = DATE(s.date_of_last_request)
LEFT JOIN dim_date           dd_last_contact
       ON dd_last_contact.full_date = DATE(s.date_of_last_contact)
WHERE s.rn = 1;
