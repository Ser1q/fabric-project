IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO


-- Dimension tables
IF OBJECT_ID('gold.DimDate', 'U') IS NOT NULL DROP TABLE gold.DimDate;

CREATE TABLE gold.DimDate
(
    date_key        INT          NOT NULL,
    full_date       DATE         NOT NULL,
    year            SMALLINT     NOT NULL,
    quarter         SMALLINT     NOT NULL,
    month           SMALLINT     NOT NULL,
    month_name      VARCHAR(10)  NOT NULL,
    month_abbr      VARCHAR(3)   NOT NULL,
    week_of_year    SMALLINT     NOT NULL,
    day_of_month    SMALLINT     NOT NULL,
    day_of_week     SMALLINT     NOT NULL,
    day_name        VARCHAR(10)  NOT NULL,
    day_abbr        VARCHAR(3)   NOT NULL,
    is_weekend      BIT          NOT NULL,
    is_leap_year    BIT          NOT NULL,
    year_month      VARCHAR(7)   NOT NULL,
    year_quarter    VARCHAR(7)   NOT NULL
);
GO

IF OBJECT_ID('gold.DimZone', 'U') IS NOT NULL DROP TABLE gold.DimZone;

CREATE TABLE gold.DimZone
(
    location_id     INT          NOT NULL,
    borough         VARCHAR(50)  NOT NULL,
    zone_name       VARCHAR(100) NOT NULL,
    service_zone    VARCHAR(50)      NULL,
    is_airport      BIT          NOT NULL    
);
GO

IF OBJECT_ID('gold.DimLocation', 'U') IS NOT NULL DROP TABLE gold.DimLocation;

CREATE TABLE gold.DimLocation
(
    location_key    VARCHAR(64)  NOT NULL,
    location_id     BIGINT           NULL,
    location_name   VARCHAR(200)     NULL,
    latitude        FLOAT            NULL,
    longitude       FLOAT            NULL
);
GO

IF OBJECT_ID('gold.DimFX', 'U') IS NOT NULL DROP TABLE gold.DimFX;

CREATE TABLE gold.DimFX
(
    year                INT     NOT NULL,
    avg_usd_eur_rate    FLOAT   NOT NULL,
    min_usd_eur_rate    FLOAT       NULL,
    max_usd_eur_rate    FLOAT       NULL,
    trading_days        INT         NULL
);
GO

IF OBJECT_ID('gold.DimGDP', 'U') IS NOT NULL DROP TABLE gold.DimGDP;

CREATE TABLE gold.DimGDP
(
    country_iso3        VARCHAR(3)   NOT NULL,
    country_name        VARCHAR(100)     NULL,
    year                INT          NOT NULL,
    gdp_usd             FLOAT            NULL,
    avg_usd_eur_rate    FLOAT            NULL,
    gdp_eur             FLOAT            NULL
);
GO


-- Fact tables
IF OBJECT_ID('gold.FactTaxiDaily', 'U') IS NOT NULL DROP TABLE gold.FactTaxiDaily;

CREATE TABLE gold.FactTaxiDaily
(
    date_key                INT      NOT NULL,
    pu_location_id          INT      NOT NULL,
    total_trips             BIGINT   NOT NULL,
    total_passengers        BIGINT       NULL,
    sum_fare_usd            FLOAT        NULL,
    avg_fare_usd            FLOAT        NULL,
    sum_total_amount_usd    FLOAT        NULL,
    avg_total_amount_usd    FLOAT        NULL,
    sum_fare_eur            FLOAT        NULL,
    avg_fare_eur            FLOAT        NULL,
    sum_tip_usd             FLOAT        NULL,
    avg_tip_usd             FLOAT        NULL,
    sum_distance_miles      FLOAT        NULL,
    avg_distance_miles      FLOAT        NULL,
    avg_duration_min        FLOAT        NULL,
    airport_trips           BIGINT       NULL,
    pct_airport             FLOAT        NULL
);
GO

IF OBJECT_ID('gold.FactAirQualityDaily', 'U') IS NOT NULL DROP TABLE gold.FactAirQualityDaily;

CREATE TABLE gold.FactAirQualityDaily
(
    date_key            INT         NOT NULL,
    location_key        VARCHAR(64) NOT NULL,
    avg_pm25            FLOAT           NULL,
    avg_no2             FLOAT           NULL,
    avg_o3              FLOAT           NULL,
    aqi_category        VARCHAR(30)     NULL
);
GO


-- Cross-domain analytical views
CREATE OR ALTER VIEW gold.vw_taxi_daily_enriched AS
SELECT
    f.date_key,
    d.full_date,
    d.year,
    d.month,
    d.month_name,
    d.day_name,
    d.is_weekend,
    d.year_quarter,
    z.borough,
    z.zone_name,
    z.service_zone,
    z.is_airport                        AS zone_is_airport,
    f.total_trips,
    f.total_passengers,
    f.avg_fare_usd,
    f.sum_fare_usd,
    f.avg_fare_eur,
    f.sum_fare_eur,
    f.avg_tip_usd,
    f.avg_distance_miles,
    f.avg_duration_min,
    f.airport_trips,
    f.pct_airport
FROM gold.FactTaxiDaily        f
JOIN gold.DimDate              d ON d.date_key    = f.date_key
JOIN gold.DimZone              z ON z.location_id = f.pu_location_id;
GO

CREATE OR ALTER VIEW gold.vw_air_quality_daily_enriched AS
SELECT
    f.date_key,
    d.full_date,
    d.year,
    d.month,
    d.month_name,
    d.day_name,
    d.is_weekend,
    d.year_quarter,
    l.location_name,
    l.latitude,
    l.longitude,
    f.avg_pm25,
    f.avg_no2,
    f.avg_o3,
    f.aqi_category
FROM gold.FactAirQualityDaily  f
JOIN gold.DimDate              d ON d.date_key     = f.date_key
JOIN gold.DimLocation          l ON l.location_key = f.location_key;
GO

CREATE OR ALTER VIEW gold.vw_mobility_vs_air_quality AS
SELECT
    d.full_date,
    d.year,
    d.month,
    d.month_name,
    d.day_name,
    d.is_weekend,
    SUM(t.total_trips)          AS city_total_trips,
    SUM(t.total_passengers)     AS city_total_passengers,
    AVG(t.avg_fare_usd)         AS city_avg_fare_usd,
    SUM(t.sum_fare_usd)         AS city_sum_fare_usd,
    AVG(a.avg_pm25)             AS city_avg_pm25,
    AVG(a.avg_no2)              AS city_avg_no2,
    AVG(a.avg_o3)               AS city_avg_o3
FROM gold.DimDate                  d
LEFT JOIN gold.FactTaxiDaily       t ON t.date_key = d.date_key
LEFT JOIN gold.FactAirQualityDaily a ON a.date_key = d.date_key
WHERE d.year BETWEEN 2020 AND 2030
GROUP BY
    d.full_date, d.year, d.month, d.month_name,
    d.day_name, d.is_weekend;
GO

CREATE OR ALTER VIEW gold.vw_economic_context AS
SELECT
    g.year,
    g.country_iso3,
    g.country_name,
    g.gdp_usd,
    g.gdp_eur,
    g.avg_usd_eur_rate,
    SUM(t.total_trips)      AS yearly_trips,
    SUM(t.sum_fare_usd)     AS yearly_fare_usd,
    SUM(t.sum_fare_eur)     AS yearly_fare_eur
FROM gold.DimGDP                    g
LEFT JOIN gold.DimDate              d ON d.year      = g.year
LEFT JOIN gold.FactTaxiDaily        t ON t.date_key  = d.date_key
GROUP BY
    g.year, g.country_iso3, g.country_name,
    g.gdp_usd, g.gdp_eur, g.avg_usd_eur_rate;
GO

CREATE OR ALTER VIEW gold.vw_borough_daily_summary AS
SELECT
    d.full_date,
    d.year,
    d.month,
    d.month_name,
    d.is_weekend,
    z.borough,
    SUM(f.total_trips)          AS total_trips,
    SUM(f.total_passengers)     AS total_passengers,
    SUM(f.sum_fare_usd)         AS sum_fare_usd,
    SUM(f.sum_fare_eur)         AS sum_fare_eur,
    AVG(f.avg_fare_usd)         AS avg_fare_usd,
    AVG(f.avg_distance_miles)   AS avg_distance_miles,
    AVG(f.avg_duration_min)     AS avg_duration_min,
    SUM(f.airport_trips)        AS airport_trips
FROM gold.FactTaxiDaily        f
JOIN gold.DimDate              d ON d.date_key    = f.date_key
JOIN gold.DimZone              z ON z.location_id = f.pu_location_id
GROUP BY
    d.full_date, d.year, d.month, d.month_name,
    d.is_weekend, z.borough;
GO