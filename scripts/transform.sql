TRUNCATE TABLE
    mart.fact_measurement,
    mart.parameter_min_max;
    --mart.limit_exceedances;

INSERT INTO mart.fact_measurement (
    sensor_id,
    parameter_name,
    location_id,
    period_from,
    period_to,
    value,
    has_flags,
    percent_complete,
    run_id
)
SELECT
    p.sensor_id,
    s.parameter_name,
    s.location_id,
    p.period_from,
    p.period_to,
    p.value,
    p.has_flags,
    p.percent_complete,
    p.run_id
FROM staging.parameter_values_raw as p
JOIN mart.dim_sensor as s ON p.sensor_id = s.sensor_id;

-- Päevane parameetrite kõikumine (min/max) eri linnades (lisasin keskmise ka, vb põnev vaadata keskmist eri aastaaegadel vms)
INSERT INTO mart.parameter_min_max (
    location_id,
    parameter_name,
    measure_date,
    min_value,
    max_value,
    avg_value,
    measurement_count
)
SELECT
    f.location_id,
    f.parameter_name,
    (f.period_from AT TIME ZONE l.timezone)::date AS measure_date,
    MIN(f.value) AS min_value,
    MAX(f.value) AS max_value,
    AVG(f.value) AS avg_value,
    COUNT(f.value) AS measurement_count
FROM mart.fact_measurement AS f
JOIN mart.dim_location AS l
    ON l.location_id = f.location_id
WHERE f.value IS NOT NULL AND f.has_flags IS NOT TRUE          
GROUP BY
    f.location_id,
    f.parameter_name,
    (f.period_from AT TIME ZONE l.timezone)::date
ON CONFLICT (location_id, parameter_name, measure_date)
DO UPDATE SET
    min_value         = EXCLUDED.min_value,
    max_value         = EXCLUDED.max_value,
    avg_value         = EXCLUDED.avg_value,
    measurement_count = EXCLUDED.measurement_count,
    computed_at       = now();
