/* =========================================================
   02_lead_dims.sql
   - Lead-related dimensions:
     * dim_lead_status
     * dim_lead_type
     * dim_contact_method
     * dim_lead_source
     * dim_campaign
   ========================================================= */

CREATE DATABASE IF NOT EXISTS realestate_dwh;
USE realestate_dwh;

/* =========================================================
   2.1) dim_lead_status (Funnel)
   ========================================================= */
DROP TABLE IF EXISTS fact_sale;

DROP TABLE IF EXISTS fact_lead;

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
        WHEN status_name = 'Congrats... It''s a sale!' THEN 1 ELSE 0
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
    FROM realestate_stg.stg_leads
    WHERE status_name IS NOT NULL
) s;


/* =========================================================
   2.2) dim_lead_type
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
    FROM realestate_stg.stg_leads
    WHERE lead_type IS NOT NULL
      AND TRIM(lead_type) <> ''
) t;


/* =========================================================
   2.3) dim_contact_method
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
        WHEN LOWER(raw_val) IN ('youtube') THEN 'youtube'

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

        WHEN LOWER(raw_val) IN ('nawy partners form') THEN 'partner form'

        WHEN LOWER(raw_val) IN (
            'app', 'mobile_app', 'app contact form', 'ambassador app',
            'broker app'
        ) THEN 'app'

        WHEN LOWER(raw_val) IN (
            'client referral', 'management referral', 'internal referral',
            'through friends'
        ) THEN 'referral'

        WHEN LOWER(raw_val) IN ('phone', 'cold call', 'sms') THEN 'phone/sms'

        WHEN LOWER(raw_val) IN ('callcenter') THEN 'call center'

        WHEN LOWER(raw_val) IN (
            'walk-in', 'corporate deals', 'bay 7 event', 'personal'
        ) THEN 'offline'

        WHEN LOWER(raw_val) IN (
            'broker', 'broker app', 'resale sheet', 'amwaj sheet'
        ) THEN 'broker/partner'

        WHEN LOWER(raw_val) IN ('blog') THEN 'blog'

        WHEN LOWER(raw_val) IN ('intercom', 'owners portal') THEN 'internal tool'

        WHEN LOWER(raw_val) IN (
            'generic list', 'direct', 'vodafone', 'cpn vodafone 1',
            'propertyfinder'
        ) THEN 'other known'

        WHEN LOWER(raw_val) IN ('(none)', 'test', '2024-06-19 00:00:00')
            THEN 'unknown'

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

        WHEN LOWER(raw_val) IN ('phone', 'cold call', 'sms', 'vodafone', 'cpn vodafone 1')
            THEN 'PHONE_SMS'

        WHEN LOWER(raw_val) IN ('callcenter') THEN 'CALL_CENTER'

        WHEN LOWER(raw_val) IN ('walk-in', 'corporate deals', 'bay 7 event', 'personal')
            THEN 'OFFLINE'

        WHEN LOWER(raw_val) IN ('intercom', 'owners portal') THEN 'INTERNAL'

        WHEN LOWER(raw_val) IN ('generic list', 'direct') THEN 'OTHER'

        WHEN LOWER(raw_val) IN ('(none)', 'test', '2024-06-19 00:00:00')
            THEN 'UNKNOWN'

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
    CASE WHEN LOWER(raw_val) = 'callcenter' THEN 1 ELSE 0 END AS is_call_center,

    -- is_offline
    CASE
        WHEN LOWER(raw_val) IN ('walk-in', 'corporate deals', 'bay 7 event', 'personal')
            THEN 1
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
    FROM realestate_stg.stg_leads
    WHERE method_of_contact IS NOT NULL
      AND TRIM(method_of_contact) <> ''
) src;


/* =========================================================
   2.4) dim_lead_source
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
        WHEN LOWER(raw_val) LIKE '%youtube%'   THEN 'youtube'
        WHEN LOWER(raw_val) LIKE 'whatsapp%'   THEN 'whatsapp'

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
    FROM realestate_stg.stg_leads
    WHERE lead_source IS NOT NULL
      AND TRIM(lead_source) <> ''
) s;


/* =========================================================
   2.5) dim_campaign
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
            TRIM(campaign)        AS raw_campaign,
            LOWER(TRIM(campaign)) AS lc_campaign
        FROM realestate_stg.stg_leads
    ) c
) t;


/* =========================================================
   2.6) Helpful indexes on lead dims
   ========================================================= */

CREATE INDEX idx_dim_status_raw             ON dim_lead_status(raw_status_name);
CREATE INDEX idx_dim_lead_type_id           ON dim_lead_type(lead_type_id);
CREATE INDEX idx_dim_contact_method_raw     ON dim_contact_method(raw_contact_method);
CREATE INDEX idx_dim_lead_source_raw        ON dim_lead_source(raw_lead_source);
CREATE INDEX idx_dim_campaign_raw_campaign  ON dim_campaign(raw_campaign);
