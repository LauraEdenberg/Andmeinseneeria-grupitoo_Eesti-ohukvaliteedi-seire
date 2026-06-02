CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS quality;

-- staatiline asukoha dimensioonitabel
CREATE TABLE IF NOT EXISTS mart.dim_location (
    location_id text PRIMARY KEY,
    location_name text NOT NULL,
    latitude numeric(9, 4) NOT NULL,
    longitude numeric(9, 4) NOT NULL,
    country_code text NOT NULL,
    timezone text NOT NULL
);

-- staatiline parameetrite dimensioon
CREATE TABLE IF NOT EXISTS mart.dim_parameter (
    parameter_name text PRIMARY KEY,
    display_name text NOT NULL,
    default_unit text NOT NULL,
    description text NOT NULL
);

-- staatiline sensorite dimensioon
CREATE TABLE IF NOT EXISTS mart.dim_sensor (
    sensor_id text PRIMARY KEY,
    parameter_name text NOT NULL REFERENCES mart.dim_parameter (parameter_name),
    location_id text NOT NULL REFERENCES mart.dim_location (location_id),
    unit text NOT NULL
);

-- staatiline saasteainete piirmäärade dimensioonitabel (riigiteataja)
CREATE TABLE IF NOT EXISTS mart.dim_parameter_limits (
    limit_id serial PRIMARY KEY,
    parameter_name text NOT NULL REFERENCES mart.dim_parameter (parameter_name),
    limit_type text NOT NULL CHECK (limit_type IN ('limit', 'target')),
    limit_value numeric(10, 4) NOT NULL,
    unit text NOT NULL,
    averaging_period text NOT NULL,
    averaging_period_hours integer,
    allowed_exceedances_per_year integer,
    legal_basis text,
    valid_from date NOT NULL,
    valid_until date,
    notes text
);

-- staatiline EU AirQualityIndex'i saasteainete hindamisvahemikud; teeme, kui jõuame
-- CREATE TABLE IF NOT EXISTS mart.dim_AQI_bands ();

-- pipeline'i metaandmed
CREATE TABLE IF NOT EXISTS staging.pipeline_runs (
    run_id uuid PRIMARY KEY,
    fetched_at timestamptz NOT NULL,
    source_name text NOT NULL,
    datetime_from timestamptz NOT NULL,
    datetime_to timestamptz NOT NULL,
    status text NOT NULL,
    message text
);

-- toorandmed
CREATE TABLE IF NOT EXISTS staging.parameter_values_raw (
    run_id uuid NOT NULL REFERENCES staging.pipeline_runs (run_id), 
    sensor_id text NOT NULL REFERENCES mart.dim_sensor (sensor_id),
    period_from timestamptz NOT NULL,
    period_to timestamptz NOT NULL,
    period_interval text,
    value numeric(12, 6),
    has_flags boolean, -- api päringus olev andmekval. näitaja, mida saame ka ise kasutada
    percent_complete numeric(5, 2), -- api päringu andmekval. näitaja, mida saame ka ise kasutada
    fetched_at timestamptz NOT NULL,
    source_url text NOT NULL,
    PRIMARY KEY (sensor_id, period_from)
);    

-- mõõtmistulemuste faktitabel, milles on viited dimensioonidele
CREATE TABLE IF NOT EXISTS mart.fact_measurement (
    sensor_id text NOT NULL REFERENCES mart.dim_sensor (sensor_id),
    parameter_name text NOT NULL REFERENCES mart.dim_parameter (parameter_name),
    location_id text NOT NULL REFERENCES mart.dim_location (location_id),
    period_from timestamptz NOT NULL,
    period_to timestamptz NOT NULL,
    value numeric(12, 6),
    has_flags boolean,
    percent_complete numeric(5, 2),
    run_id uuid NOT NULL REFERENCES staging.pipeline_runs (run_id),
    PRIMARY KEY (sensor_id, period_from)
);

-- tabel päevaste min/max tulmuste kohta eri linnades + AVG lisaks
CREATE TABLE IF NOT EXISTS mart.parameter_min_max (
    location_id text NOT NULL REFERENCES mart.dim_location (location_id),
    parameter_name text NOT NULL REFERENCES mart.dim_parameter (parameter_name),
    measure_date date NOT NULL,
    min_value numeric(12, 6),
    max_value numeric(12, 6),
    avg_value numeric(12, 6),
    measurement_count integer NOT NULL,
    computed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (location_id, parameter_name, measure_date)
);

-- Superseti tarbeks vaade, milles on olemas nö inimloetavad nimed ehk location_name ja display_name
CREATE OR REPLACE VIEW mart.v_parameter_min_max AS
SELECT
    mm.location_id,
    l.location_name,
    mm.parameter_name,
    p.display_name AS parameter_display_name,
    p.default_unit AS unit,
    mm.measure_date,
    mm.min_value,
    mm.max_value,
    mm.avg_value,
    mm.measurement_count
FROM mart.parameter_min_max AS mm
JOIN mart.dim_location AS l ON l.location_id = mm.location_id
JOIN mart.dim_parameter AS p ON p.parameter_name = mm.parameter_name;
