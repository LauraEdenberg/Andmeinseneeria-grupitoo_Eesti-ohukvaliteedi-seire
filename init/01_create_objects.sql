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
    datetime_to timestamptz NOT NULL, -- seda hetkel ei ole data_from_api.py koodis parameetrite all, vaja lisada, kui tahame päritud andmete ajavahemiku infot oma metaandmetesse
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
    PRIMARY KEY (run_id, sensor_id, period_from),
    UNIQUE (sensor_id, period_from) --lisasin unikaalsuse piirangu, et sama sensori sama perioodi andmeid ei saaks topelt sisestada, vaid uuendatakse olemasolevat rida
);    


