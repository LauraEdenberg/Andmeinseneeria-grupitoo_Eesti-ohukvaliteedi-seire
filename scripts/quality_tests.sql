CREATE SCHEMA IF NOT EXISTS quality;

CREATE TABLE IF NOT EXISTS quality.test_results (
    test_run_at timestamptz NOT NULL DEFAULT now(),
    test_name text NOT NULL,
    status text NOT NULL,
    failed_rows integer NOT NULL,
    message text NOT NULL
);

TRUNCATE TABLE quality.test_results;

WITH latest_run AS (
    SELECT run_id
    FROM staging.pipeline_runs
    WHERE status = 'success'
    ORDER BY fetched_at DESC
    LIMIT 1
),
test_cases AS (
    SELECT 
	    'dim_location_has_rows' AS test_name,
        CASE 
    	    WHEN (SELECT COUNT(*) FROM mart.dim_location) > 0 THEN 0
            ELSE 1
            END AS failed_rows,
        'Asukohtade dimensioonis peab olema vähemalt üks rida.' AS message

    UNION ALL

    SELECT 
	    'dim_parameter_has_rows' AS test_name,
        CASE 
    	    WHEN (SELECT COUNT(*) FROM mart.dim_parameter) > 0 THEN 0
            ELSE 1
         END AS failed_rows,
        'Parameetrite dimensioonis peab olema vähemalt üks rida.' AS message

    UNION ALL

    SELECT 
	    'dim_sensor_has_rows' AS test_name,
        CASE 
    	    WHEN (SELECT COUNT(*) FROM mart.dim_sensor) > 0 THEN 0
            ELSE 1
            END AS failed_rows,
        'Sensorite dimensioonis peab olema vähemalt üks rida.' AS message

    UNION ALL

    SELECT 
	    'dim_parameter_limits_has_rows' AS test_name,
        CASE 
    	    WHEN (SELECT COUNT(*) FROM mart.dim_parameter_limits) > 0 THEN 0
            ELSE 1
            END AS failed_rows,
        'Saasteainete piirmäärade dimensioonis peab olema vähemalt üks rida.' AS message

    UNION ALL

    SELECT 
	    'parameter_values_raw_has_rows' AS test_name,
        CASE 
    	    WHEN EXISTS(
                    SELECT 1 
                    FROM staging.parameter_values_raw
                    )
                    THEN 0
            ELSE 1
            END AS failed_rows,
        'APIst andmete laadimisel peab olema vähemalt üks rida.' AS message

    UNION ALL

    SELECT
        'check_for_duplicates' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Sama sensori, kuupäeva ja ajavahemiku kohta võib olla üks rida.' AS message
    FROM (
        SELECT
            sensor_id,
            period_from,
            COUNT(*) AS row_count
        FROM staging.parameter_values_raw AS p
        INNER JOIN latest_run AS r ON p.run_id = r.run_id
        GROUP BY 
            sensor_id,
            period_from
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT 
        'concentrations_reasonable' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Saasteaine kontsentratsioon ei tohi olla negatiivne.' AS message
    FROM staging.parameter_values_raw AS p
    INNER JOIN latest_run AS r ON p.run_id = r.run_id
    WHERE value < 0

	UNION ALL

    SELECT
        'max_min_not_null' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Max ja min ei tohi olla NULL.' AS message
    FROM mart.parameter_min_max
    WHERE min_value IS NULL OR max_value IS NULL 
	
	UNION ALL

    SELECT 
        'no_of_exceedances_not_null' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Piirmäärade ületamise arv ei tohi olla NULL.' AS message
    FROM mart.v_limit_exceedances
    WHERE no_of_exceedances IS NULL
)

INSERT INTO quality.test_results (
    test_name,
    status,
    failed_rows,
    message
)
SELECT
    test_name,
    CASE WHEN failed_rows = 0 THEN 'passed' ELSE 'failed' END AS status,
    failed_rows,
    message
FROM test_cases
ORDER BY test_name;
