/* =========================================================
   03_core_dims.sql
   - dim_date
   - dim_customer
   - dim_agent
   - dim_area
   - dim_compound
   - dim_developer
   - indexes on natural keys
   ========================================================= */

USE realestate_dwh;

/* =========================================================
   3.1) dim_date
   ========================================================= */

-- DROP TABLE IF EXISTS dim_date;
-- DROP PROCEDURE IF EXISTS populate_dim_date;

-- CREATE TABLE dim_date (
--     date_key        INT PRIMARY KEY,      -- 20100101 style
--     full_date       DATE NOT NULL,
--     year            INT NOT NULL,
--     quarter         TINYINT NOT NULL,
--     month           TINYINT NOT NULL,
--     month_name      VARCHAR(20) NOT NULL,
--     day_of_month    TINYINT NOT NULL,
--     day_of_week     TINYINT NOT NULL,     -- MySQL: 1=Sunday ... 7=Saturday
--     day_name        VARCHAR(20) NOT NULL,
--     week_of_year    TINYINT NOT NULL,
--     is_weekend      TINYINT NOT NULL      -- 1 = Fri/Sat (Egypt), 0 otherwise
-- ) ENGINE=InnoDB;

-- DELIMITER $$

-- CREATE PROCEDURE populate_dim_date (
--     IN p_start_date DATE,
--     IN p_end_date   DATE
-- )
-- BEGIN
--     DELETE FROM dim_date;

--     INSERT INTO dim_date (
--         date_key,
--         full_date,
--         year,
--         quarter,
--         month,
--         month_name,
--         day_of_month,
--         day_of_week,
--         day_name,
--         week_of_year,
--         is_weekend
--     )
--     SELECT
--         CAST(DATE_FORMAT(d, '%Y%m%d') AS SIGNED) AS date_key,
--         d AS full_date,
--         YEAR(d) AS year,
--         QUARTER(d) AS quarter,
--         MONTH(d) AS month,
--         DATE_FORMAT(d, '%M') AS month_name,
--         DAY(d) AS day_of_month,
--         DAYOFWEEK(d) AS day_of_week,
--         DATE_FORMAT(d, '%W') AS day_name,
--         WEEK(d, 3) AS week_of_year,
--         CASE
--             WHEN DAYOFWEEK(d) IN (6, 7) THEN 1
--             ELSE 0
--         END AS is_weekend
--     FROM (
--         SELECT
--             DATE_ADD(
--                 p_start_date,
--                 INTERVAL seq DAY
--             ) AS d
--         FROM (
--             SELECT
--                 d0.i
--                 + 10    * d1.i
--                 + 100   * d2.i
--                 + 1000  * d3.i
--                 + 10000 * d4.i AS seq
--             FROM
--                 (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
--                  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d0
--             CROSS JOIN
--                 (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
--                  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d1
--             CROSS JOIN
--                 (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
--                  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d2
--             CROSS JOIN
--                 (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
--                  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d3
--             CROSS JOIN
--                 (SELECT 0 i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
--                  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d4
--         ) x
--     ) dates
--     WHERE d BETWEEN p_start_date AND p_end_date
--     ORDER BY d;
-- END$$

-- DELIMITER ;

-- CALL populate_dim_date('2010-01-01', '2040-12-31');


/* =========================================================
   3.2) dim_customer
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
FROM realestate_stg.stg_leads
WHERE customer_id IS NOT NULL;


/* =========================================================
   3.3) dim_agent
   ========================================================= */

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
FROM realestate_stg.stg_leads
WHERE user_id IS NOT NULL;


/* =========================================================
   3.4) dim_area
   ========================================================= */

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
    SELECT area_id FROM realestate_stg.stg_leads
    UNION
    SELECT area_id FROM realestate_stg.stg_sales
) x
WHERE area_id IS NOT NULL;


/* =========================================================
   3.5) dim_compound
   ========================================================= */

DROP TABLE IF EXISTS dim_compound;

CREATE TABLE dim_compound (
    compound_key   INT AUTO_INCREMENT PRIMARY KEY,
    compound_id    DOUBLE NOT NULL,
    compound_name  VARCHAR(255)
);

INSERT INTO dim_compound (compound_id)
SELECT DISTINCT compound_id
FROM (
    SELECT compound_id FROM realestate_stg.stg_leads
    UNION
    SELECT compound_id FROM realestate_stg.stg_sales
) x
WHERE compound_id IS NOT NULL;


/* =========================================================
   3.6) dim_developer
   ========================================================= */

DROP TABLE IF EXISTS dim_developer;

CREATE TABLE dim_developer (
    developer_key   INT AUTO_INCREMENT PRIMARY KEY,
    developer_id    DOUBLE NOT NULL,
    developer_name  VARCHAR(255) NULL,
    developer_group VARCHAR(100) NULL
);

INSERT INTO dim_developer (developer_id)
SELECT DISTINCT developer_id
FROM realestate_stg.stg_leads
WHERE developer_id IS NOT NULL;


/* =========================================================
   3.7) Indexes on core dims
   ========================================================= */

CREATE INDEX idx_dim_customer_customer_id   ON dim_customer(customer_id);
CREATE INDEX idx_dim_agent_user_id          ON dim_agent(user_id);
CREATE INDEX idx_dim_area_area_id           ON dim_area(area_id);
CREATE INDEX idx_dim_compound_compound_id   ON dim_compound(compound_id);
CREATE INDEX idx_dim_developer_developer_id ON dim_developer(developer_id);
