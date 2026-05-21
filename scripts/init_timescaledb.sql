CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Weather metrics 
CREATE TABLE IF NOT EXISTS weather_metrics (
    time            TIMESTAMPTZ     NOT NULL,
    city            TEXT            NOT NULL,
    country         TEXT            NOT NULL DEFAULT 'US',

    -- Temperature
    temp_c          DOUBLE PRECISION,        
    feels_like_c    DOUBLE PRECISION,
    temp_min_c      DOUBLE PRECISION,
    temp_max_c      DOUBLE PRECISION,

    -- Atmosphere
    humidity_pct    DOUBLE PRECISION,        
    pressure_hpa    DOUBLE PRECISION,
    visibility_m    DOUBLE PRECISION,

    -- Wind
    wind_speed_ms   DOUBLE PRECISION,        
    wind_deg        DOUBLE PRECISION,        
    wind_gust_ms    DOUBLE PRECISION,

    -- Precipitation
    rain_1h_mm      DOUBLE PRECISION DEFAULT 0,
    snow_1h_mm      DOUBLE PRECISION DEFAULT 0,

    -- Cloud cover / condition
    cloud_pct       DOUBLE PRECISION,       
    weather_id      INTEGER,                 
    weather_main    TEXT,                    
    weather_desc    TEXT,                   

    -- Enrichment from Fabric Gold layer (joined by the ETL job)
    taxi_trips_day  INTEGER,                
    avg_fare_usd    DOUBLE PRECISION       
);

SELECT create_hypertable(
    'weather_metrics', 'time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_weather_city_time
    ON weather_metrics (city, time DESC);


CREATE MATERIALIZED VIEW IF NOT EXISTS weather_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time)  AS bucket,
    city,
    AVG(temp_c)                  AS avg_temp_c,
    AVG(humidity_pct)            AS avg_humidity,
    AVG(wind_speed_ms)           AS avg_wind_ms,
    SUM(rain_1h_mm)              AS total_rain_mm,
    SUM(snow_1h_mm)              AS total_snow_mm,
    AVG(cloud_pct)               AS avg_cloud_pct,
    AVG(taxi_trips_day)          AS avg_taxi_trips,
    COUNT(*)                     AS sample_count
FROM weather_metrics
GROUP BY bucket, city
WITH NO DATA;

-- Daily rollup
CREATE MATERIALIZED VIEW IF NOT EXISTS weather_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', time)   AS bucket,
    city,
    AVG(temp_c)                  AS avg_temp_c,
    MIN(temp_c)                  AS min_temp_c,
    MAX(temp_c)                  AS max_temp_c,
    AVG(humidity_pct)            AS avg_humidity,
    AVG(wind_speed_ms)           AS avg_wind_ms,
    SUM(rain_1h_mm)              AS total_rain_mm,
    SUM(snow_1h_mm)              AS total_snow_mm,
    MODE() WITHIN GROUP (
        ORDER BY weather_main
    )                            AS dominant_condition,
    AVG(taxi_trips_day)          AS avg_taxi_trips,
    AVG(avg_fare_usd)            AS avg_fare_usd
FROM weather_metrics
GROUP BY bucket, city
WITH NO DATA;

-- Refresh policies
SELECT add_continuous_aggregate_policy('weather_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset   => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

SELECT add_continuous_aggregate_policy('weather_daily',
    start_offset => INTERVAL '3 days',
    end_offset   => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);
