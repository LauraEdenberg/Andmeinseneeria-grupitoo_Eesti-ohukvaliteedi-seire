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

-- ühe tunni andmed, millest edasi eri keskmistamise perioodide tulemusi arvutada ja piirmääradega võrrelda
WITH hourly AS (
    SELECT
        location_id,
        parameter_name,
        value,
        period_from,
        EXTRACT(YEAR FROM period_from) AS year,
        date_trunc('day', period_from) AS day
    FROM mart.fact_measurement
),
-- 1_hour: kasutab hourly value otse võrdluseks ületamiste arvu loendamiseks
exceedance_1h AS (
    SELECT
        h.location_id,
        h.parameter_name,
        h.year,
        l.allowed_exceedances_per_year,
        SUM(CASE WHEN h.value > l.limit_value THEN 1 ELSE 0 END) AS no_of_exceedances
    FROM hourly AS h
    JOIN mart.dim_parameter_limits AS l ON h.parameter_name = l.parameter_name
    AND l.averaging_period = '1_hour'
    GROUP BY h.location_id, h.parameter_name, h.year, l.allowed_exceedances_per_year
),
-- 24_hour: esmalt arvutab päeva keskmise, seejärel loendab päevaste ületamiste arvu
daily_avg AS (
    SELECT
        location_id,
        parameter_name,
        year,
        day,
        AVG(value) AS daily_value
    FROM hourly
    GROUP BY location_id, parameter_name, year, day
),
exceedance_24h AS (
    SELECT
        d.location_id,
        d.parameter_name,
        d.year,
        l.allowed_exceedances_per_year,
        SUM(CASE WHEN d.daily_value > l.limit_value THEN 1 ELSE 0 END) AS no_of_exceedances
    FROM daily_avg AS d
    JOIN mart.dim_parameter_limits AS l ON d.parameter_name = l.parameter_name
    AND l.averaging_period = '24_hours'
    GROUP BY d.location_id, d.parameter_name, d.year, l.allowed_exceedances_per_year
),
-- 1_year: ühe aasta keskmise võrdlemine piirmääraga ja ületuste arvu loendamine
exceedance_1y AS (
    SELECT
        h.location_id,
        h.parameter_name,
        h.year,
        l.allowed_exceedances_per_year,
        CASE WHEN AVG(h.value) > l.limit_value THEN 1 ELSE 0 END AS no_of_exceedances
    FROM hourly AS h
    JOIN mart.dim_parameter_limits AS l ON h.parameter_name = l.parameter_name
    AND l.averaging_period = '1_year'
    GROUP BY h.location_id, h.parameter_name, h.year, l.allowed_exceedances_per_year, l.limit_value
)
-- hinnangute koondtabel koos keskmistamise perioodiga
SELECT
    location_id,
    parameter_name,
    averaging_period,
    year,
    no_of_exceedances,
    allowed_exceedances_per_year,
    CASE
        WHEN allowed_exceedances_per_year IS NULL AND no_of_exceedances > 0
            THEN 'aasta keskmine ületab piirmäära'
        WHEN allowed_exceedances_per_year IS NULL
            THEN 'tulemus on normide piires'
        WHEN no_of_exceedances > allowed_exceedances_per_year
            THEN 'piirmäära ületatud lubatust suurem arv kordi'
        ELSE 'tulemus on normide piires'
    END AS result
FROM (
    SELECT location_id, parameter_name, year, allowed_exceedances_per_year, no_of_exceedances, '1_hour' AS averaging_period FROM exceedance_1h
    UNION ALL
    SELECT location_id, parameter_name, year, allowed_exceedances_per_year, no_of_exceedances, '24_hours' AS averaging_period FROM exceedance_24h
    UNION ALL
    SELECT location_id, parameter_name, year, allowed_exceedances_per_year, no_of_exceedances, '1_year' AS averaging_period FROM exceedance_1y
) AS combined
ORDER BY location_id, parameter_name, averaging_period, year;

/*
SELECT
    location_id,
    parameter_name,
    year,
    no_of_exceedances,
    allowed_exceedances_per_year,
    CASE
        WHEN no_of_exceedances > allowed_exceedances_per_year
        THEN 'piirmäära ületatud lubatust suurem arv kordi'
        ELSE 'tulemus on normi piires'
    END AS result
FROM (
    SELECT
        f.location_id,
        f.parameter_name,
        EXTRACT(YEAR FROM period_from) AS year,
        SUM(CASE WHEN f.value > l.limit_value THEN 1 ELSE 0 END) AS no_of_exceedances,
        l.allowed_exceedances_per_year
    FROM mart.fact_measurement AS f
    JOIN mart.dim_parameter_limits AS l ON f.parameter_name = l.parameter_name
    GROUP BY f.location_id, f.parameter_name, EXTRACT(YEAR FROM period_from), l.allowed_exceedances_per_year
) AS report
ORDER BY location_id, parameter_name, year;
*/
