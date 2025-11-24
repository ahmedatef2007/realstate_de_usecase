/* =========================================================
   REAL ESTATE DWH – LEADS BUSINESS PROCESS
   ========================================================= */
CREATE DATABASE IF NOT EXISTS realestate_stg;
USE realestate_stg;


/* =========================================================
   1) STAGING TABLES
   ========================================================= */

DROP TABLE IF EXISTS realestate_stg.stg_leads;

CREATE TABLE realestate_stg.stg_leads AS
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


-- Sales staging kept for future Sales fact (not used yet here)
DROP TABLE IF EXISTS realestate_stg.stg_sales;

CREATE TABLE realestate_stg.stg_sales AS
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



/* =========================================================
   2) DIMENSIONS – LEAD STATUS (FUNNEL)
   Funnel stage reference: https://www.salesmate.io/blog/real-estate-sales-funnel/
   ========================================================= */
CREATE DATABASE IF NOT EXISTS realestate_dwh;
USE realestate_dwh;

DROP TABLE IF EXISTS dim_lead_status;

CREATE TABLE dim_lead_status (
    lead_status_key   INT AUTO_INCREMENT PRIMARY KEY,
    raw_status_name   VARCHAR(255) NOT NULL,
    normalized_status VARCHAR(100) NOT NULL,
    funnel_stage      VARCHAR(50)  NOT NULL,
    is_won            TINYINT      NOT NULL DEFAULT 0,
    is_lost           TINYINT      NOT NULL DEFAULT 0,
    is_active         TINYINT      NOT NULL DEFAULT 1
);

INSERT INTO dim_lead_status (
    raw_status_name,
    normalized_status,
    funnel_stage,
    is_won,
    is_lost,
    is_active
)
SELECT
    status_name AS raw_status_name,

    -- normalized_status
    CASE
        WHEN status_name IN (
            'Needs to be contacted',
            'Needs to be contacted (FRESH)',
            'Needs to be contacted (Reassigned)',
            'Needs to be contacted Resale',
            'Call Center only (Unkown)'
        ) THEN 'to_contact'

        WHEN status_name IN (
            'No answer',
            'No answer (First call)',
            'Switched off',
            'Client not available'
        ) THEN 'no_answer'

        WHEN status_name IN (
            'Meeting scheduled',
            'Another Meeting scheduled',
            'Zoom meeting scheduled',
            'Another Zoom Meeting scheduled',
            'Confirm meeting'
        ) THEN 'meeting_scheduled'

        WHEN status_name IN (
            'Meeting',
            'Physical Meeting happened',
            'Meeting Follow up',
            'Another Meeting Happened',
            'Zoom meeting happened',
            'Another Zoom meeting happened',
            'Presentation',
            'Presentation (ready to move)'
        ) THEN 'meeting_done'

        WHEN status_name IN (
            'EOI',
            'Unit Blocked',
            'Unit Reserved',
            'Awaiting contract signing'
        ) THEN 'reservation_stage'

        WHEN status_name IN (
            'Contract Signed',
            'Rejected Contract',
            'Finalize deal',
            'Primary Buyer'
        ) THEN 'contract_stage'

        WHEN status_name = 'Congrats... It''s a sale!' THEN 'sale_won'

        WHEN status_name IN (
            'Wrong number',
            'Not a client',
            'Low budget',
            'Invalid location',
            'Bought outside',
            'Bought outside compound',
            '(Call Center Only) Rubbish',
            'Not interested'
        ) THEN 'disqualified'

        WHEN status_name IN ('Reassigning', 'Reassigned Handover')
            THEN 'reassigned'

        WHEN status_name IN ('Meeting canceled')
            THEN 'meeting_canceled'

        ELSE 'other'
    END AS normalized_status,

    -- funnel_stage
    CASE
        WHEN status_name IN (
            'Needs to be contacted',
            'Needs to be contacted (FRESH)',
            'Needs to be contacted (Reassigned)',
            'Needs to be contacted Resale',
            'Call Center only (Unkown)'
        ) THEN 'TO_CONTACT'

        WHEN status_name IN (
            'No answer',
            'No answer (First call)',
            'Switched off',
            'Client not available'
        ) THEN 'CONTACT_ATTEMPT'

        WHEN status_name IN (
            'Meeting scheduled',
            'Another Meeting scheduled',
            'Zoom meeting scheduled',
            'Another Zoom Meeting scheduled',
            'Confirm meeting'
        ) THEN 'MEETING_BOOKED'

        WHEN status_name IN (
            'Meeting',
            'Physical Meeting happened',
            'Meeting Follow up',
            'Another Meeting Happened',
            'Zoom meeting happened',
            'Another Zoom meeting happened',
            'Presentation',
            'Presentation (ready to move)'
        ) THEN 'MEETING_HELD'

        WHEN status_name IN (
            'EOI',
            'Unit Blocked',
            'Unit Reserved',
            'Awaiting contract signing'
        ) THEN 'RESERVATION'

        WHEN status_name IN (
            'Contract Signed',
            'Rejected Contract',
            'Finalize deal',
            'Primary Buyer'
        ) THEN 'CONTRACT'

        WHEN status_name = 'Congrats... It''s a sale!' THEN 'WON'

        WHEN status_name IN (
            'Wrong number',
            'Not a client',
            'Low budget',
            'Invalid location',
            'Bought outside',
            'Bought outside compound',
            '(Call Center Only) Rubbish',
            'Not interested'
        ) THEN 'DISQUALIFIED'

        WHEN status_name IN ('Reassigning', 'Reassigned Handover')
            THEN 'INTERNAL_REASSIGN'

        WHEN status_name = 'Meeting canceled'
            THEN 'MEETING_CANCELED'

        ELSE 'OTHER'
    END AS funnel_stage,

    -- is_won
    CASE
        WHEN status_name = 'Congrats... It''s a sale!'
            THEN 1
        ELSE 0
    END AS is_won,

    -- is_lost
    CASE
        WHEN status_name IN (
            'Wrong number',
            'Not a client',
            'Low budget',
            'Invalid location',
            'Bought outside',
            'Bought outside compound',
            '(Call Center Only) Rubbish',
            'Not interested'
        ) THEN 1
        ELSE 0
    END AS is_lost,

    -- is_active
    CASE
        WHEN status_name IN (
            'Congrats... It''s a sale!',
            'Wrong number',
            'Not a client',
            'Low budget',
            'Invalid location',
            'Bought outside',
            'Bought outside compound',
            '(Call Center Only) Rubbish',
            'Not interested'
        ) THEN 0
        ELSE 1
    END AS is_active
FROM (
    SELECT DISTINCT status_name
    FROM realestate_dwh.stg_leads
    WHERE status_name IS NOT NULL
) s;


/* =========================================================
   3) DIMENSIONS – LEAD TYPE
   ========================================================= */


DROP TABLE IF EXISTS dim_lead_type;

CREATE TABLE dim_lead_type (
    lead_type_key    INT AUTO_INCREMENT PRIMARY KEY,
    lead_type_id     INT,
    lead_type_name   VARCHAR(100) NOT NULL,
    lead_type_group  VARCHAR(50),
    is_commercial    TINYINT NOT NULL DEFAULT 0
);

INSERT INTO dim_lead_type (
    lead_type_id,
    lead_type_name,
    lead_type_group,
    is_commercial
)
SELECT
    lead_type_id,
    lead_type_name,
    
    CASE
        WHEN lead_type_name = 'Primary' THEN 'PRIMARY'
        WHEN lead_type_name IN ('Resale Buyer', 'Seller') THEN 'RESALE'
        WHEN lead_type_name = 'Nawy Now' THEN 'INSTANT_BUY'
        WHEN lead_type_name IN ('Commercial Buyer', 'Commercial Seller', 'Commercial Rental')
            THEN 'COMMERCIAL'
        WHEN lead_type_name IN ('Brokerage', 'Freelancer', 'Ambassador')
            THEN 'REFERRAL_BROKER'
        ELSE 'OTHER'
    END AS lead_type_group,

    CASE
        WHEN lead_type_name IN ('Commercial Buyer', 'Commercial Seller', 'Commercial Rental')
            THEN 1
        ELSE 0
    END AS is_commercial
FROM (
    SELECT DISTINCT
        lead_type_id,
        TRIM(lead_type) AS lead_type_name
    FROM realestate_dwh.stg_leads
    WHERE lead_type IS NOT NULL
      AND TRIM(lead_type) <> ''
) t;


/* =========================================================
   4) DIMENSIONS – CONTACT METHOD
   ========================================================= */

DROP TABLE IF EXISTS dim_contact_method;

CREATE TABLE dim_contact_method (
    contact_method_key    INT AUTO_INCREMENT PRIMARY KEY,
    raw_contact_method    VARCHAR(255) NOT NULL,
    contact_method_clean  VARCHAR(255) NOT NULL,
    method_group          VARCHAR(50),
    is_digital            TINYINT NOT NULL DEFAULT 0,
    is_social             TINYINT NOT NULL DEFAULT 0,
    is_call_center        TINYINT NOT NULL DEFAULT 0,
    is_offline            TINYINT NOT NULL DEFAULT 0,
    is_referral           TINYINT NOT NULL DEFAULT 0
);

INSERT INTO dim_contact_method (
    raw_contact_method,
    contact_method_clean,
    method_group,
    is_digital,
    is_social,
    is_call_center,
    is_offline,
    is_referral
)
SELECT
    raw_val AS raw_contact_method,

    -- contact_method_clean
    CASE
        WHEN LOWER(raw_val) IN (
            'facebook', 'facebook comment', 'facebook message',
            'facebook page referral', 'l.facebook.com', 'form facebook'
        ) THEN 'facebook'
        WHEN LOWER(raw_val) IN (
            'instagram', 'instagram message'
        ) THEN 'instagram'
        WHEN LOWER(raw_val) IN (
            'linkedin', 'linkedin.com', 'com.linkedin.android'
        ) THEN 'linkedin'
        WHEN LOWER(raw_val) IN (
            'youtube'
        ) THEN 'youtube'

        WHEN LOWER(raw_val) IN (
            'google', 'form google', 'google lead form', 'google,google',
            'r.search.yahoo.com', 'search.yahoo.com', 'bing.com',
            'timebusinessnews.com', 'realitypaper.com',
            'magazines2day.com', 'evokingminds.com', 'amirarticles.com',
            '10bestseo.com', 'www-cooingestate-com.cdn.ampproject.org',
            'newchat.ktree.org', 'localhost'
        ) THEN 'search/web'

        WHEN LOWER(raw_val) IN (
            'generic form', 'organic form', 'top compounds form',
            'form', 'type form', 'resale form', 'elite form',
            'generic contact us form'
        ) THEN 'website form'

        WHEN LOWER(raw_val) IN (
            'form adwords', 'snapchat lead form', 'dynamicremarketing',
            'criteo', 'propertyfinder'
        ) THEN 'paid ads form'

        WHEN LOWER(raw_val) IN (
            'nawy partners form'
        ) THEN 'partner form'

        WHEN LOWER(raw_val) IN (
            'app', 'mobile_app', 'app contact form', 'ambassador app',
            'broker app'
        ) THEN 'app'

        WHEN LOWER(raw_val) IN (
            'client referral', 'management referral', 'internal referral',
            'through friends'
        ) THEN 'referral'

        WHEN LOWER(raw_val) IN (
            'phone', 'cold call', 'sms'
        ) THEN 'phone/sms'

        WHEN LOWER(raw_val) IN (
            'callcenter'
        ) THEN 'call center'

        WHEN LOWER(raw_val) IN (
            'walk-in', 'corporate deals', 'bay 7 event', 'personal'
        ) THEN 'offline'

        WHEN LOWER(raw_val) IN (
            'broker', 'broker app', 'resale sheet', 'amwaj sheet'
        ) THEN 'broker/partner'

        WHEN LOWER(raw_val) IN (
            'blog'
        ) THEN 'blog'

        WHEN LOWER(raw_val) IN (
            'intercom', 'owners portal'
        ) THEN 'internal tool'

        WHEN LOWER(raw_val) IN (
            'generic list', 'direct', 'vodafone', 'cpn vodafone 1',
            'propertyfinder'
        ) THEN 'other known'

        WHEN LOWER(raw_val) IN (
            '(none)', 'test', '2024-06-19 00:00:00'
        ) THEN 'unknown'

        ELSE 'other'
    END AS contact_method_clean,

    -- method_group
    CASE
        WHEN LOWER(raw_val) IN (
            'facebook', 'facebook comment', 'facebook message',
            'facebook page referral', 'l.facebook.com', 'form facebook',
            'instagram', 'instagram message',
            'youtube',
            'linkedin', 'linkedin.com', 'com.linkedin.android'
        ) THEN 'SOCIAL'

        WHEN LOWER(raw_val) IN (
            'google', 'form google', 'google lead form', 'google,google',
            'r.search.yahoo.com', 'search.yahoo.com', 'bing.com',
            'timebusinessnews.com', 'realitypaper.com',
            'magazines2day.com', 'evokingminds.com', 'amirarticles.com',
            '10bestseo.com', 'www-cooingestate-com.cdn.ampproject.org',
            'newchat.ktree.org', 'localhost', 'blog'
        ) THEN 'SEARCH_ORGANIC'

        WHEN LOWER(raw_val) IN (
            'generic form', 'organic form', 'top compounds form',
            'form', 'type form', 'resale form', 'elite form',
            'generic contact us form', 'website'
        ) THEN 'WEBSITE_FORM'

        WHEN LOWER(raw_val) IN (
            'form adwords', 'snapchat lead form', 'dynamicremarketing',
            'criteo', 'propertyfinder'
        ) THEN 'PAID_ADS'

        WHEN LOWER(raw_val) IN (
            'app', 'mobile_app', 'app contact form',
            'ambassador app', 'broker app', 'ambassador app'
        ) THEN 'APP'

        WHEN LOWER(raw_val) IN (
            'nawy partners form', 'broker', 'broker app',
            'resale sheet', 'amwaj sheet'
        ) THEN 'BROKER_PARTNER'

        WHEN LOWER(raw_val) IN (
            'client referral', 'management referral', 'internal referral',
            'through friends'
        ) THEN 'REFERRAL'

        WHEN LOWER(raw_val) IN (
            'phone', 'cold call', 'sms', 'vodafone', 'cpn vodafone 1'
        ) THEN 'PHONE_SMS'

        WHEN LOWER(raw_val) IN (
            'callcenter'
        ) THEN 'CALL_CENTER'

        WHEN LOWER(raw_val) IN (
            'walk-in', 'corporate deals', 'bay 7 event', 'personal'
        ) THEN 'OFFLINE'

        WHEN LOWER(raw_val) IN (
            'intercom', 'owners portal'
        ) THEN 'INTERNAL'

        WHEN LOWER(raw_val) IN (
            'generic list', 'direct'
        ) THEN 'OTHER'

        WHEN LOWER(raw_val) IN (
            '(none)', 'test', '2024-06-19 00:00:00'
        ) THEN 'UNKNOWN'

        ELSE 'OTHER'
    END AS method_group,

    -- is_digital
    CASE
        WHEN LOWER(raw_val) IN (
            'facebook', 'facebook comment', 'facebook message',
            'facebook page referral', 'l.facebook.com', 'form facebook',
            'instagram', 'instagram message',
            'youtube',
            'linkedin', 'linkedin.com', 'com.linkedin.android',
            'google', 'form google', 'google lead form', 'google,google',
            'r.search.yahoo.com', 'search.yahoo.com', 'bing.com',
            'timebusinessnews.com', 'realitypaper.com',
            'magazines2day.com', 'evokingminds.com', 'amirarticles.com',
            '10bestseo.com', 'www-cooingestate-com.cdn.ampproject.org',
            'newchat.ktree.org', 'localhost',
            'generic form', 'organic form', 'top compounds form',
            'form', 'type form', 'resale form', 'elite form',
            'generic contact us form', 'website',
            'form adwords', 'snapchat lead form', 'dynamicremarketing',
            'criteo', 'propertyfinder',
            'app', 'mobile_app', 'app contact form',
            'ambassador app', 'broker app',
            'intercom', 'owners portal'
        ) THEN 1
        ELSE 0
    END AS is_digital,

    -- is_social
    CASE
        WHEN LOWER(raw_val) IN (
            'facebook', 'facebook comment', 'facebook message',
            'facebook page referral', 'l.facebook.com', 'form facebook',
            'instagram', 'instagram message',
            'youtube',
            'linkedin', 'linkedin.com', 'com.linkedin.android'
        ) THEN 1
        ELSE 0
    END AS is_social,

    -- is_call_center
    CASE
        WHEN LOWER(raw_val) IN ('callcenter') THEN 1
        ELSE 0
    END AS is_call_center,

    -- is_offline
    CASE
        WHEN LOWER(raw_val) IN (
            'walk-in', 'corporate deals', 'bay 7 event', 'personal'
        ) THEN 1
        ELSE 0
    END AS is_offline,

    -- is_referral
    CASE
        WHEN LOWER(raw_val) IN (
            'client referral', 'management referral',
            'internal referral', 'through friends'
        ) THEN 1
        ELSE 0
    END AS is_referral
FROM (
    SELECT DISTINCT TRIM(method_of_contact) AS raw_val
    FROM realestate_dwh.stg_leads
    WHERE method_of_contact IS NOT NULL
      AND TRIM(method_of_contact) <> ''
) AS src;


/* =========================================================
   5) DIMENSIONS – LEAD SOURCE
   ========================================================= */

DROP TABLE IF EXISTS dim_lead_source;

CREATE TABLE dim_lead_source (
    lead_source_key    INT AUTO_INCREMENT PRIMARY KEY,
    raw_lead_source    VARCHAR(255),
    lead_source_clean  VARCHAR(255) NOT NULL,
    source_group       VARCHAR(50),
    is_social          TINYINT NOT NULL DEFAULT 0,
    is_partner         TINYINT NOT NULL DEFAULT 0,
    is_offline         TINYINT NOT NULL DEFAULT 0,
    is_organic         TINYINT NOT NULL DEFAULT 0,
    is_paid            TINYINT NOT NULL DEFAULT 0
);

INSERT INTO dim_lead_source (
    raw_lead_source,
    lead_source_clean,
    source_group,
    is_social,
    is_partner,
    is_offline,
    is_organic,
    is_paid
)
SELECT
    raw_val AS raw_lead_source,

    -- lead_source_clean
    CASE
        WHEN raw_val IS NULL OR TRIM(raw_val) = '' THEN 'unknown'

        WHEN LOWER(raw_val) LIKE '%facebook%' THEN 'facebook'
        WHEN LOWER(raw_val) LIKE '%instagram%' THEN 'instagram'
        WHEN LOWER(raw_val) LIKE '%youtube%' THEN 'youtube'
        WHEN LOWER(raw_val) LIKE 'whatsapp%' THEN 'whatsapp'

        WHEN LOWER(raw_val) LIKE 'google%'
          OR LOWER(raw_val) LIKE '%google.com%'
          OR LOWER(raw_val) LIKE '%google_ads%'
          OR LOWER(raw_val) LIKE '%googleads.g.doubleclick.net%'
          OR LOWER(raw_val) LIKE 'form google'
          OR LOWER(raw_val) IN (
                'search.yahoo.com','r.search.yahoo.com','bing.com',
                'magazines2day.com','amirarticles.com','evokingminds.com',
                'realitypaper.com','10bestseo.com','timebusinessnews.com'
            )
        THEN 'google/search'

        WHEN LOWER(raw_val) LIKE '%propertyfinder%' THEN 'propertyfinder'

        WHEN LOWER(raw_val) LIKE '%website%'
          OR LOWER(raw_val) LIKE '%landing page%'
          OR LOWER(raw_val) LIKE '%form%'
          OR LOWER(raw_val) IN ('organic form','organic search','organic')
        THEN 'website/form'

        WHEN LOWER(raw_val) IN ('broker','broker app','nawy partners form','resale sheet','amwaj sheet')
        THEN 'broker/partner'

        WHEN LOWER(raw_val) LIKE '%referral%'
          OR LOWER(raw_val) LIKE '%through friends%'
          OR LOWER(raw_val) LIKE '%cooing client referral%'
        THEN 'referral'

        WHEN LOWER(raw_val) IN ('intercom','owners portal','old cooing client')
        THEN 'internal'

        WHEN LOWER(raw_val) IN (
            'walk-in','bay 7 event','corporate deals','hotline',
            'phone','sms','callcenter','call center resale'
        )
        THEN 'offline'

        WHEN LOWER(raw_val) IN ('direct','direct traffic','(none)','unknown')
        THEN 'direct/unknown'

        ELSE TRIM(raw_val)
    END AS lead_source_clean,

    -- source_group
    CASE
        WHEN LOWER(raw_val) LIKE '%facebook%'
          OR LOWER(raw_val) LIKE '%instagram%'
          OR LOWER(raw_val) LIKE '%youtube%'
          OR LOWER(raw_val) LIKE '%linkedin%'
        THEN 'SOCIAL'

        WHEN LOWER(raw_val) LIKE 'google%'
          OR LOWER(raw_val) LIKE '%google.com%'
          OR LOWER(raw_val) IN (
                'search.yahoo.com','r.search.yahoo.com','bing.com',
                'magazines2day.com','amirarticles.com','evokingminds.com',
                'realitypaper.com','10bestseo.com','timebusinessnews.com'
            )
        THEN 'SEARCH'

        WHEN LOWER(raw_val) LIKE '%form%'
          OR LOWER(raw_val) LIKE '%website%'
          OR LOWER(raw_val) LIKE '%landing page%'
          OR LOWER(raw_val) IN ('organic form','organic search','organic')
        THEN 'OWNED_MEDIA'

        WHEN LOWER(raw_val) LIKE '%propertyfinder%' THEN 'PORTAL'

        WHEN LOWER(raw_val) IN ('broker','broker app','nawy partners form','resale sheet','amwaj sheet')
        THEN 'PARTNER'

        WHEN LOWER(raw_val) LIKE '%referral%'
          OR LOWER(raw_val) LIKE '%through friends%'
          OR LOWER(raw_val) LIKE '%cooing client referral%'
        THEN 'REFERRAL'

        WHEN LOWER(raw_val) IN (
            'walk-in','bay 7 event','corporate deals','hotline',
            'phone','sms','callcenter','call center resale'
        )
        THEN 'OFFLINE'

        WHEN LOWER(raw_val) IN ('intercom','owners portal','old cooing client')
        THEN 'INTERNAL'

        WHEN LOWER(raw_val) LIKE 'whatsapp%' THEN 'MESSAGING'

        ELSE 'OTHER'
    END AS source_group,

    -- is_social
    CASE
        WHEN LOWER(raw_val) LIKE '%facebook%'
          OR LOWER(raw_val) LIKE '%instagram%'
          OR LOWER(raw_val) LIKE '%youtube%'
          OR LOWER(raw_val) LIKE '%linkedin%'
        THEN 1 ELSE 0
    END AS is_social,

    -- is_partner
    CASE
        WHEN LOWER(raw_val) IN ('broker','broker app','nawy partners form','resale sheet','amwaj sheet')
        THEN 1 ELSE 0
    END AS is_partner,

    -- is_offline
    CASE
        WHEN LOWER(raw_val) IN (
            'walk-in','bay 7 event','corporate deals','hotline',
            'phone','sms','callcenter','call center resale'
        )
        THEN 1 ELSE 0
    END AS is_offline,

    -- is_organic
    CASE
        WHEN LOWER(raw_val) IN ('organic','organic form','organic search')
             OR LOWER(raw_val) LIKE '%organic%'
        THEN 1 ELSE 0
    END AS is_organic,

    -- is_paid
    CASE
        WHEN LOWER(raw_val) IN ('paid search','googleads.g.doubleclick.net','google_ads','dynamicremarketing','criteo')
             OR LOWER(raw_val) LIKE '%cpc%'
             OR LOWER(raw_val) LIKE '%paid%'
        THEN 1 ELSE 0
    END AS is_paid
FROM (
    SELECT DISTINCT TRIM(lead_source) AS raw_val
    FROM realestate_dwh.stg_leads
    WHERE lead_source IS NOT NULL
      AND TRIM(lead_source) <> ''
) s;


/* =========================================================
   6) DIMENSION – CAMPAIGN
   ========================================================= */

DROP TABLE IF EXISTS dim_campaign;

CREATE TABLE dim_campaign (
    campaign_key      INT AUTO_INCREMENT PRIMARY KEY,
    raw_campaign      VARCHAR(255),
    campaign_clean    VARCHAR(255),
    campaign_type     VARCHAR(50),
    is_brand          TINYINT NOT NULL DEFAULT 0,
    is_remarketing    TINYINT NOT NULL DEFAULT 0
);

INSERT INTO dim_campaign (
    raw_campaign,
    campaign_clean,
    campaign_type,
    is_brand,
    is_remarketing
)
SELECT
    raw_campaign,
    campaign_clean,
    campaign_type,
    is_brand,
    is_remarketing
FROM (
    SELECT
        raw_campaign,

        -- clean version
        CASE
            WHEN raw_campaign IS NULL
                 OR TRIM(raw_campaign) = ''
                 OR raw_campaign IN ('0', '(none)')
            THEN 'Unknown'
            ELSE TRIM(
                    REPLACE(
                      REPLACE(raw_campaign, '%20', ' '),
                      '  ', ' '
                    )
                 )
        END AS campaign_clean,

        -- type buckets
        CASE
            WHEN lc_campaign LIKE '%remarket%' THEN 'REMARKETING'
            WHEN lc_campaign LIKE '%brand%'    THEN 'BRAND'
            WHEN lc_campaign LIKE '%prospect%' THEN 'PROSPECTING'
            WHEN lc_campaign LIKE '%sms%'      THEN 'SMS'
            WHEN lc_campaign LIKE '%pmax%' 
              OR lc_campaign LIKE '%display%'
              OR lc_campaign LIKE '%retarget%'
              OR lc_campaign LIKE '%demandgen%'
            THEN 'PERFORMANCE_DISPLAY'
            ELSE 'OTHER'
        END AS campaign_type,

        -- flags
        CASE
            WHEN lc_campaign LIKE '%brand%' THEN 1 ELSE 0
        END AS is_brand,

        CASE
            WHEN lc_campaign LIKE '%remarket%' THEN 1 ELSE 0
        END AS is_remarketing
    FROM (
        SELECT DISTINCT
            TRIM(campaign)           AS raw_campaign,
            LOWER(TRIM(campaign))    AS lc_campaign
        FROM realestate_dwh.stg_leads
    ) c
) t;

SELECT COUNT(DISTINCT campaign_clean) FROM dim_campaign;


/* =========================================================
   7) DIMENSION – DATE
   ========================================================= */

DROP TABLE IF EXISTS dim_date;
DROP PROCEDURE IF EXISTS populate_dim_date;

CREATE TABLE dim_date (
    date_key        INT PRIMARY KEY,      -- 20100101 style
    full_date       DATE NOT NULL,
    year            INT NOT NULL,
    quarter         TINYINT NOT NULL,
    month           TINYINT NOT NULL,
    month_name      VARCHAR(20) NOT NULL,
    day_of_month    TINYINT NOT NULL,
    day_of_week     TINYINT NOT NULL,     -- MySQL: 1=Sunday ... 7=Saturday
    day_name        VARCHAR(20) NOT NULL,
    week_of_year    TINYINT NOT NULL,
    is_weekend      TINYINT NOT NULL      -- 1 = Fri/Sat (Egypt), 0 otherwise
) ENGINE=InnoDB;

DELIMITER $$

CREATE PROCEDURE populate_dim_date (
    IN p_start_date DATE,
    IN p_end_date   DATE
)
BEGIN
    DELETE FROM dim_date;

    INSERT INTO dim_date (
        date_key,
        full_date,
        year,
        quarter,
        month,
        month_name,
        day_of_month,
        day_of_week,
        day_name,
        week_of_year,
        is_weekend
    )
    SELECT
        CAST(DATE_FORMAT(d, '%Y%m%d') AS SIGNED) AS date_key,
        d AS full_date,
        YEAR(d) AS year,
        QUARTER(d) AS quarter,
        MONTH(d) AS month,
        DATE_FORMAT(d, '%M') AS month_name,
        DAY(d) AS day_of_month,
        DAYOFWEEK(d) AS day_of_week,
        DATE_FORMAT(d, '%W') AS day_name,
        WEEK(d, 3) AS week_of_year,
        CASE
            WHEN DAYOFWEEK(d) IN (6, 7) THEN 1
            ELSE 0
        END AS is_weekend
    FROM (
        SELECT
            DATE_ADD(
                p_start_date,
                INTERVAL seq DAY
            ) AS d
        FROM (
            SELECT
                d0.i
                + 10    * d1.i
                + 100   * d2.i
                + 1000  * d3.i
                + 10000 * d4.i AS seq
            FROM
                (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d0
            CROSS JOIN
                (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d1
            CROSS JOIN
                (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d2
            CROSS JOIN
                (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d3
            CROSS JOIN
                (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d4
        ) AS x
    ) AS dates
    WHERE d BETWEEN p_start_date AND p_end_date
    ORDER BY d;
END$$

DELIMITER ;

CALL populate_dim_date('2010-01-01', '2040-12-31');



/* =========================================================
   8) DIMENSIONS – CUSTOMER, AGENT, AREA, COMPOUND, DEVELOPER
   ========================================================= */

DROP TABLE IF EXISTS dim_customer;

CREATE TABLE dim_customer (
    customer_key    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id     BIGINT NOT NULL,
    customer_name   VARCHAR(255) NULL DEFAULT NULL,
    customer_email  VARCHAR(255) NULL DEFAULT NULL
);

INSERT INTO dim_customer (customer_id)
SELECT DISTINCT
    customer_id
FROM realestate_dwh.stg_leads
WHERE customer_id IS NOT NULL;


DROP TABLE IF EXISTS dim_agent;

CREATE TABLE dim_agent (
    agent_key   INT AUTO_INCREMENT PRIMARY KEY,
    user_id     DOUBLE NOT NULL,
    agent_name  VARCHAR(255),
    team_name   VARCHAR(255)
);

INSERT INTO dim_agent (user_id)
SELECT DISTINCT
    user_id
FROM realestate_dwh.stg_leads
WHERE user_id IS NOT NULL;


DROP TABLE IF EXISTS dim_area;

CREATE TABLE dim_area (
    area_key   INT AUTO_INCREMENT PRIMARY KEY,
    area_id    DOUBLE NOT NULL,
    area_name  VARCHAR(255),
    city       VARCHAR(255),
    region     VARCHAR(255)
);

INSERT INTO dim_area (area_id)
SELECT DISTINCT area_id
FROM (
    SELECT area_id FROM realestate_dwh.stg_leads
    -- UNION
    -- SELECT area_id FROM realestate_dwh.stg_sales
) x
WHERE area_id IS NOT NULL;


DROP TABLE IF EXISTS dim_compound;

CREATE TABLE dim_compound (
    compound_key   INT AUTO_INCREMENT PRIMARY KEY,
    compound_id    DOUBLE NOT NULL,
    compound_name  VARCHAR(255)
);

INSERT INTO dim_compound (compound_id)
SELECT DISTINCT compound_id
FROM (
    SELECT compound_id FROM realestate_dwh.stg_leads
    -- UNION
    -- SELECT compound_id FROM realestate_dwh.stg_sales
) x
WHERE compound_id IS NOT NULL;


DROP TABLE IF EXISTS dim_developer;

CREATE TABLE dim_developer (
    developer_key   INT AUTO_INCREMENT PRIMARY KEY,
    developer_id    DOUBLE NOT NULL,
    developer_name  VARCHAR(255) NULL,
    developer_group VARCHAR(100) NULL
);

INSERT INTO dim_developer (developer_id)
SELECT DISTINCT developer_id
FROM realestate_dwh.stg_leads
WHERE developer_id IS NOT NULL;



/* =========================================================
   10) FACT – LEAD
   ========================================================= */

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
    CASE WHEN s.buyer       = 1 THEN 1 ELSE 0 END AS is_buyer,
    CASE WHEN s.seller      = 1 THEN 1 ELSE 0 END AS is_seller,
    CASE WHEN s.commercial  = 1 THEN 1 ELSE 0 END AS is_commercial,
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
    FROM realestate_dwh.stg_leads sl
) s
LEFT JOIN dim_customer       dc    ON dc.customer_id        = s.customer_id
LEFT JOIN dim_agent          da    ON da.user_id            = s.user_id
LEFT JOIN dim_lead_status    dls   ON dls.raw_status_name   = s.status_name
LEFT JOIN dim_lead_type      dlt   ON dlt.lead_type_id      = s.lead_type_id
LEFT JOIN dim_contact_method dcm   ON dcm.raw_contact_method = TRIM(s.method_of_contact)
LEFT JOIN dim_lead_source    dlsrc ON dlsrc.raw_lead_source   = TRIM(s.lead_source)
LEFT JOIN dim_campaign       dcamp ON dcamp.raw_campaign      = TRIM(s.campaign)
LEFT JOIN dim_area           dar   ON dar.area_id             = s.area_id
LEFT JOIN dim_compound       dco   ON dco.compound_id         = s.compound_id
LEFT JOIN dim_developer      ddv   ON ddv.developer_id        = s.developer_id
LEFT JOIN dim_date           dd_created
       ON dd_created.full_date = DATE(s.created_at)
LEFT JOIN dim_date           dd_last_req
       ON dd_last_req.full_date = DATE(s.date_of_last_request)
LEFT JOIN dim_date           dd_last_contact
       ON dd_last_contact.full_date = DATE(s.date_of_last_contact)
WHERE s.rn = 1;




/* =========================================================
   11) INDEXES ON DIMENSION NATURAL KEYS
   ========================================================= */

CREATE INDEX idx_dim_customer_customer_id   ON dim_customer(customer_id);
CREATE INDEX idx_dim_agent_user_id          ON dim_agent(user_id);
CREATE INDEX idx_dim_area_area_id           ON dim_area(area_id);
CREATE INDEX idx_dim_compound_compound_id   ON dim_compound(compound_id);
CREATE INDEX idx_dim_developer_developer_id ON dim_developer(developer_id);
CREATE INDEX idx_dim_campaign_raw_campaign  ON dim_campaign(raw_campaign);
CREATE INDEX idx_dim_lead_source_raw        ON dim_lead_source(raw_lead_source);
CREATE INDEX idx_dim_contact_method_raw     ON dim_contact_method(raw_contact_method);
CREATE INDEX idx_dim_status_raw             ON dim_lead_status(raw_status_name);
CREATE INDEX idx_dim_lead_type_id           ON dim_lead_type(lead_type_id);







/* =========================================================
   SALES DIMENSIONS
   - dim_property_type
   - dim_sale_category
   Source: realestate_dwh.stg_sales
   ========================================================= */

/* ---------------------------------------------------------
   1) dim_property_type
   --------------------------------------------------------- */

DROP TABLE IF EXISTS dim_property_type;

CREATE TABLE dim_property_type (
    property_type_key    INT AUTO_INCREMENT PRIMARY KEY,
    property_type_id     INT,
    property_type_name   VARCHAR(100) NOT NULL,
    property_type_group  VARCHAR(50),
    is_residential       TINYINT NOT NULL DEFAULT 0,
    is_commercial        TINYINT NOT NULL DEFAULT 0,
    is_vacation          TINYINT NOT NULL DEFAULT 0
);

INSERT INTO dim_property_type (
    property_type_id,
    property_type_name,
    property_type_group,
    is_residential,
    is_commercial,
    is_vacation
)
SELECT
    t.property_type_id,
    t.property_type_name,

    /* Grouping */
    CASE
        WHEN UPPER(t.property_type_name) IN ('APARTMENT','DUPLEX','PENTHOUSE','STUDIO','SERVICED APARTMENT','FAMILY HOUSE')
            THEN 'RESIDENTIAL_APT'
        WHEN UPPER(t.property_type_name) IN ('VILLA','TOWNHOUSE','TWINHOUSE')
            THEN 'RESIDENTIAL_VILLA'
        WHEN UPPER(t.property_type_name) IN ('CHALET','CABIN')
            THEN 'VACATION'
        WHEN UPPER(t.property_type_name) IN ('OFFICE','RETAIL','CLINIC')
            THEN 'COMMERCIAL'
        ELSE 'OTHER'
    END AS property_type_group,

    /* Flags */
    CASE
        WHEN UPPER(t.property_type_name) IN (
            'APARTMENT','DUPLEX','PENTHOUSE','STUDIO','SERVICED APARTMENT',
            'FAMILY HOUSE','VILLA','TOWNHOUSE','TWINHOUSE'
        )
            THEN 1
        ELSE 0
    END AS is_residential,

    CASE
        WHEN UPPER(t.property_type_name) IN ('OFFICE','RETAIL','CLINIC')
            THEN 1
        ELSE 0
    END AS is_commercial,

    CASE
        WHEN UPPER(t.property_type_name) IN ('CHALET','CABIN')
            THEN 1
        ELSE 0
    END AS is_vacation

FROM (
    SELECT DISTINCT
        property_type_id AS property_type_id,
        TRIM(property_type)          AS property_type_name
    FROM realestate_stg.stg_sales
    WHERE property_type IS NOT NULL
      AND TRIM(property_type) <> ''
) t;


/* ---------------------------------------------------------
   2) dim_sale_category
   --------------------------------------------------------- */

DROP TABLE IF EXISTS dim_sale_category;

CREATE TABLE dim_sale_category (
    sale_category_key     INT AUTO_INCREMENT PRIMARY KEY,
    raw_sale_category     VARCHAR(255),
    sale_category_clean   VARCHAR(100) NOT NULL,
    sale_category_group   VARCHAR(50),
    is_primary            TINYINT NOT NULL DEFAULT 0,
    is_resale             TINYINT NOT NULL DEFAULT 0,
    is_developer          TINYINT NOT NULL DEFAULT 0,
    is_instant_buy        TINYINT NOT NULL DEFAULT 0
);

INSERT INTO dim_sale_category (
    raw_sale_category,
    sale_category_clean,
    sale_category_group,
    is_primary,
    is_resale,
    is_developer,
    is_instant_buy
)
SELECT
    raw_val AS raw_sale_category,

    /* Clean label */
    CASE
        WHEN raw_val IS NULL OR TRIM(raw_val) = '' THEN 'Unknown'
        ELSE TRIM(raw_val)
    END AS sale_category_clean,

    /* Grouping */
    CASE
        WHEN raw_val = 'Primary'
            THEN 'PRIMARY'
        WHEN raw_val IN ('Resale Buyer','Resale Seller','Developer Resale')
            THEN 'RESALE'
        WHEN raw_val = 'Developer Commercial Sale'
            THEN 'DEVELOPER_COMMERCIAL'
        WHEN raw_val = 'Nawy Now'
            THEN 'INSTANT_BUY'
        ELSE 'OTHER'
    END AS sale_category_group,

    /* Flags */
    CASE
        WHEN raw_val = 'Primary' THEN 1 ELSE 0
    END AS is_primary,

    CASE
        WHEN raw_val IN ('Resale Buyer','Resale Seller','Developer Resale')
            THEN 1
        ELSE 0
    END AS is_resale,

    CASE
        WHEN raw_val IN ('Developer Commercial Sale','Developer Resale')
            THEN 1
        ELSE 0
    END AS is_developer,

    CASE
        WHEN raw_val = 'Nawy Now' THEN 1 ELSE 0
    END AS is_instant_buy

FROM (
    SELECT DISTINCT sale_category AS raw_val
    FROM realestate_stg.stg_sales
) s;


USE realestate_dwh;

DROP TABLE IF EXISTS fact_sale;

CREATE TABLE fact_sale (
    sale_id                 BIGINT PRIMARY KEY,
    lead_id                 BIGINT,          -- to join back to fact_lead

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
