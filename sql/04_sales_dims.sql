/* =========================================================
   04_sales_dims.sql
   - dim_property_type
   - dim_sale_category
   Source: realestate_stg.stg_sales
   ========================================================= */

USE realestate_dwh;

/* ---------------------------------------------------------
   4.1) dim_property_type
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
        property_type_id,
        TRIM(property_type) AS property_type_name
    FROM realestate_stg.stg_sales
    WHERE property_type IS NOT NULL
      AND TRIM(property_type) <> ''
) t;


/* ---------------------------------------------------------
   4.2) dim_sale_category
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

    CASE
        WHEN raw_val IS NULL OR TRIM(raw_val) = '' THEN 'Unknown'
        ELSE TRIM(raw_val)
    END AS sale_category_clean,

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

    CASE WHEN raw_val = 'Primary' THEN 1 ELSE 0 END AS is_primary,

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
