CREATE SCHEMA IF NOT EXISTS quality;

CREATE TABLE IF NOT EXISTS quality.test_results (
    test_run_at timestamptz NOT NULL DEFAULT now(),
    test_name text NOT NULL,
    status text NOT NULL,
    failed_rows integer NOT NULL,
    message text NOT NULL
);

TRUNCATE TABLE quality.test_results;

WITH test_cases AS (
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
    	WHEN (SELECT COUNT(*) FROM staging.parameter_values_raw) > 0 THEN 0
        ELSE 1
        END AS failed_rows,
    'APIst andmete laadimisel peab olema vähemalt üks rida.' AS message

#siia veel teste
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
