TRUNCATE TABLE
    mart.fact_measurement;

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
