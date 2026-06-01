INSERT INTO mart.dim_location (
    location_id,
    location_name,
    latitude,
    longitude,
    country_code,
    timezone
)
VALUES 
    ('10624', 'Tartu', 58.3780, 26.7290, 'EE', 'Europe/Tallinn'), --lat/long - igaks juhuks panin sisse, hetkel andmed pärit Wikist, peaks proovima õiged kohad OpenAQ-st kätte saada
    ('8087', 'Tallinn', 59.4370, 24.7536, 'EE', 'Europe/Tallinn'),
    ('10634', 'Narva', 59.3793, 28.1909, 'EE', 'Europe/Tallinn')
ON CONFLICT (location_id) DO UPDATE SET
    location_name = EXCLUDED.location_name,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    country_code = EXCLUDED.country_code,
    timezone = EXCLUDED.timezone;

INSERT INTO mart.dim_parameter (
    parameter_name,
    display_name,
    default_unit,
    description
)
VALUES
    ('pm25', 'PM2.5', 'µg/m³', 'Peenosake läbimõõduga kuni 2.5 µm'),
    ('pm10', 'PM10',  'µg/m³', 'Peenosake läbimõõduga kuni 10 µm'),
    ('no2',  'NO₂',   'µg/m³', 'Lämmastikdioksiid'),
    ('o3',   'O₃',    'µg/m³', 'Osoon'),
    ('so2',  'SO₂',   'µg/m³', 'Vääveldioksiid'),
ON CONFLICT (parameter_name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    default_unit = EXCLUDED.default_unit,
    description = EXCLUDED.description;

INSERT INTO mart.dim_sensor (
    sensor_id,
    parameter_name,
    location_id,
    unit
)
VALUES
    -- Tartu
    ('35307',    'no2',  '10624', 'µg/m³'),
    ('35308',    'o3',   '10624', 'µg/m³'),
    ('35316',    'pm10', '10624', 'µg/m³'),
    ('35347',    'pm25', '10624', 'µg/m³'),
    ('35358',    'so2',  '10624', 'µg/m³'),
    -- Tallinn
    ('23441',    'no2',  '8087',  'µg/m³'),
    ('23444',    'o3',   '8087',  'µg/m³'),
    ('23447',    'pm10', '8087',  'µg/m³'),
    ('23448',    'pm25', '8087',  'µg/m³'),
    ('23449',    'so2',  '8087',  'µg/m³'),
    -- Narva
    ('8613252',  'no2',  '10634', 'µg/m³'),
    ('8613163',  'o3',   '10634', 'µg/m³'),
    ('8613350',  'pm10', '10634', 'µg/m³'),
    ('8613075',  'pm25', '10634', 'µg/m³'),
    ('8613273',  'so2',  '10634', 'µg/m³')
ON CONFLICT (sensor_id) DO UPDATE SET
    parameter_name = EXCLUDED.parameter_name,
    location_id = EXCLUDED.location_id,
    unit = EXCLUDED.unit;


INSERT INTO mart.dim_parameter_limits (
    parameter_name,
    limit_type,
    limit_value,
    unit,
    averaging_period,
    averaging_period_hours,
    allowed_exceedances_per_year,
    legal_basis,
    valid_from
)
VALUES
    ('so2',  'limit', 350,   'µg/m³', '1_hour',      1,    24,   'EU 2008/50/EÜ', '2010-01-01'),
    ('so2',  'limit', 125,   'µg/m³', '24_hours',    24,   3,    'EU 2008/50/EÜ', '2010-01-01'),
    ('no2',  'limit', 200,   'µg/m³', '1_hour',      1,    18,   'EU 2008/50/EÜ', '2010-01-01'),
    ('no2',  'limit', 40,    'µg/m³', '1_year',      8760, NULL, 'EU 2008/50/EÜ', '2010-01-01'),
    ('pm10', 'limit', 50,    'µg/m³', '24_hours',    24,   35,   'EU 2008/50/EÜ', '2005-01-01'),
    ('pm10', 'limit', 40,    'µg/m³', '1_year',      8760, NULL, 'EU 2008/50/EÜ', '2005-01-01'),
    ('pm25', 'limit', 25,    'µg/m³', '1_year',      8760, NULL, 'EU 2008/50/EÜ', '2015-01-01'),
    ('o3',   'target', 120,  'µg/m³', '8_hours_max', 8,    25,   'EU 2008/50/EÜ', '2010-01-01')
ON CONFLICT DO NOTHING;

