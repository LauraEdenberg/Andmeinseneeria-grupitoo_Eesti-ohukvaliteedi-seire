SELECT
    run_id,
    fetched_at,
    source_name,
    datetime_from,
    datetime_to,
    status
FROM staging.pipeline_runs
ORDER BY fetched_at DESC
LIMIT 5;

SELECT
    location_id,
    location_name,
    latitude,
    longitude
FROM mart.dim_location
ORDER BY location_name;

SELECT
    sensor_id,
    parameter_name,
    location_id,
    unit
FROM mart.dim_sensor
ORDER BY sensor_id;

SELECT
    location_name,
    parameter_display_name,
    unit,
    measure_date,
    min_value,
    max_value,
    avg_value,
    measurement_count
FROM mart.v_parameter_min_max
ORDER BY measure_date DESC, location_name
LIMIT 10;

SELECT
    location_name,
    parameter_display_name,
    averaging_period,
    year,
    no_of_exceedances,
    allowed_exceedances_per_year,
    result
FROM mart.v_limit_exceedances
ORDER BY year DESC, location_name, parameter_display_name;

SELECT
    test_name,
    status,
    failed_rows,
    message
FROM quality.test_results
ORDER BY test_name;