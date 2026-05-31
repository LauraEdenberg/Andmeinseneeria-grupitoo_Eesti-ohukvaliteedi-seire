"""Õhukvaliteedi andmetöövoog.

Skript loeb aktiivsed asukohad staatilisest dimensioonitabelist, pärib
OpenAQ API-st mõõtmistulemised, salvestab selle `staging`
kihti, [ehitab `mart` kihis otsustamiseks sobivad tabelid] ning käivitab
kvaliteedikontrollid.
"""

from __future__ import annotations

import argparse
import os
import sys
import uuid
from datetime import datetime, timezone, timedelta
from pathlib import Path

import psycopg2
import requests


SCRIPT_DIR = Path(__file__).resolve().parent
INIT_SQL = SCRIPT_DIR.parent / "init" / "01_create_objects.sql"
DIMENSIONS_SQL = SCRIPT_DIR / "01_seed_dimensions.sql"
TRANSFORM_SQL = SCRIPT_DIR / "transform.sql" #siia vaja lisada õige transform scripti faili nimi
QUALITY_SQL = SCRIPT_DIR / "quality_tests.sql"


class UserFacingError(RuntimeError):
    """Viga, mille sõnum sobib otse õppijale näitamiseks."""


def log(message: str) -> None:
    print(message, flush=True)


def get_env(name: str, default: str) -> str:
    return os.environ.get(name, default)


def get_connection():
    return psycopg2.connect(
        host=get_env("DB_HOST", "db"),
        port=get_env("DB_PORT", "5432"),
        user=get_env("DB_USER", "praktikum"),
        password=get_env("DB_PASSWORD", "praktikum"),
        dbname=get_env("DB_NAME", "praktikum"),
    )

def init_db(conn) -> None:
    execute_sql_file(conn, INIT_SQL)

def seed_dimensions(conn) -> None:
    execute_sql_file(conn, DIMENSIONS_SQL)


def load_active_locations(conn) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                location_id,
                location_name,
                latitude,
                longitude
            FROM mart.dim_location
            ORDER BY location_name
            """
        )
        rows = cur.fetchall()

    if not rows:
        raise UserFacingError("Asukohtade dimensioonis ei ole ühtegi rida.")

    return [
        {
            "location_id": location_id,
            "location_name": location_name,
            "latitude": float(latitude),
            "longitude": float(longitude),
        }
        for location_id, location_name, latitude, longitude in rows
    ]

def load_active_sensors(conn) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT sensor_id, parameter_name, location_id, unit
            FROM mart.dim_sensor
        """)
        rows = cur.fetchall()

    return [
        {
            "sensor_id": sensor_id,
            "parameter_name": parameter_name,
            "location_id": location_id,
            "unit": unit,
        }
        for sensor_id, parameter_name, location_id, unit in rows
    ]


def insert_pipeline_run(conn, *, run_id: uuid.UUID, fetched_at: datetime, datetime_from: datetime, datetime_to: datetime) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO staging.pipeline_runs (
                run_id,
                fetched_at,
                source_name,
                datetime_from,
                datetime_to,
                status,
                message
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                str(run_id),
                fetched_at,
                "OpenAQ API",
                datetime_from,
                datetime_to,
                "running",
                "Laadimine algas.",
            ),
        )
    conn.commit()


def update_pipeline_run(conn, *, run_id: uuid.UUID, status: str, message: str) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE staging.pipeline_runs
            SET status = %s,
                message = %s
            WHERE run_id = %s
            """,
            (status, message, str(run_id)),
        )
    conn.commit()


def fetch_measurements(sensor_id: str, *, datetime_from: str, datetime_to: str, limit: int = 1000) -> tuple[str, dict]:
    base_url = get_env("OPENAQ_API_URL", "https://api.openaq.org/v3")
    api_key = get_env("OPENAQ_API_KEY", "")
    if not api_key:
        raise ValueError("Missing OPENAQ_API_KEY in environment")
    url = f"{base_url}/sensors/{sensor_id}/measurements"

    params = {
        "datetime_from": datetime_from,
        "datetime_to": datetime_to,
        "limit": limit,
    }
    headers = {
        "X-API-Key": api_key
    }
    try:
        response = requests.get(
            url,
            params=params,
            headers=headers,
            timeout=30
        )
        response.raise_for_status()

    except requests.RequestException as exc:
        raise UserFacingError(
            f"OpenAQ API päring ebaõnnestus (sensor {sensor_id}): {exc}"
        ) from exc

    try:
        payload = response.json()
    except ValueError as exc:
        raise UserFacingError(
            f"OpenAQ vastus ei olnud korrektne JSON (sensor {sensor_id})"
        ) from exc

    return response.url, payload

def get_time_window():
    now = datetime.now(timezone.utc)
    backfill_days = int(get_env("BACKFILL_DAYS", "7"))

    datetime_to = now
    datetime_from = now - timedelta(days=backfill_days)

    return datetime_from, datetime_to

def ingest_sensor_data(
    conn,
    *,
    run_id: uuid.UUID,
    sensor: dict,
    payload: dict,
    source_url: str,
    fetched_at: datetime,
):
    rows = payload.get("results", [])

    if not rows:
        return 0

    with conn.cursor() as cur:
        for r in rows:
                        
            cur.execute("""
                INSERT INTO staging.parameter_values_raw (
                    run_id,
                    sensor_id,
                    period_from,
                    period_to,
                    period_interval,
                    value,
                    has_flags,
                    percent_complete,
                    fetched_at,
                    source_url
                )
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (sensor_id, period_from)
                DO UPDATE SET
                    period_to = EXCLUDED.period_to,
                    period_interval = EXCLUDED.period_interval,
                    value = EXCLUDED.value,
                    has_flags = EXCLUDED.has_flags,
                    percent_complete = EXCLUDED.percent_complete,
                    fetched_at = EXCLUDED.fetched_at,
                    source_url = EXCLUDED.source_url
            """, (
                str(run_id),
                sensor["sensor_id"],
                r.get("period", {}).get("datetimeFrom", {}).get("utc"),
                r.get("period", {}).get("datetimeTo", {}).get("utc"),
                r.get("period", {}).get("interval"),
                r.get("value"),
                r.get("flagInfo", {}).get("hasFlags"),
                 r.get("coverage", {}).get("percentComplete"),
                fetched_at,
                source_url,
            ))

    conn.commit()
    return len(rows)


def ingest() -> uuid.UUID:
    run_id = uuid.uuid4()
    fetched_at = datetime.now(timezone.utc)
    datetime_from, datetime_to = get_time_window()
    conn = get_connection()
    try:
        init_db(conn)
        seed_dimensions(conn)
        sensors = load_active_sensors(conn)
        insert_pipeline_run(
            conn,
            run_id=run_id,
            fetched_at=fetched_at,
            datetime_from=datetime_from,
            datetime_to=datetime_to,
        )

        total_rows = 0
        for sensor in sensors:
            log(f"Toon sensori {sensor['sensor_id']} andmed alates {datetime_from} kuni {datetime_to}.")

            url, payload = fetch_measurements(
                sensor_id=sensor["sensor_id"],
                datetime_from=datetime_from.isoformat(),
                datetime_to=datetime_to.isoformat(),
            )

            rows = ingest_sensor_data(
                conn,
                run_id=run_id,
                sensor=sensor,
                payload=payload,
                source_url=url,
                fetched_at=fetched_at,
            )

            total_rows += rows
            log(f"Laadisin {sensor['sensor_id']} kohta {rows} mõõtmistulemust.")

        update_pipeline_run(
            conn,
            run_id=run_id,
            status="success",
            message=f"Laadimine õnnestus. Sensoreid: {len(sensors)}. Ridu kokku: {total_rows}.",
        )
        log(f"Andmete vastuvõtt valmis. Käivituse ID: {run_id}.")
        return run_id
    except Exception as exc:
        conn.rollback()

        try:
            update_pipeline_run(
                conn,
                run_id=run_id,
                status="error",
                message=str(exc),
            )
        except Exception:
            pass
        raise
    finally:
        conn.close()


def execute_sql_file(conn, path: Path) -> None:
    log(f"Käivitan SQL-faili {path.name}.")
    sql = path.read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def fetch_value(conn, query: str):
    with conn.cursor() as cur:
        cur.execute(query)
        return cur.fetchone()[0]


def transform() -> None:
    conn = get_connection()
    try:
        seed_dimensions(conn)
        execute_sql_file(conn, TRANSFORM_SQL)
        #daily_rows = fetch_value(conn, "SELECT COUNT(*) FROM mart.daily_weather_summary;")
        #latest_rows = fetch_value(conn, "SELECT COUNT(*) FROM mart.latest_daily_weather_summary;")
        #window_rows = fetch_value(conn, "SELECT COUNT(*) FROM mart.latest_outdoor_activity_windows;")
        #log(f"Transformatsioon valmis. Päevaseid koondridu kokku: {daily_rows}.")
        #log(f"Viimase laadimise päevaseid koondridu: {latest_rows}.")
        #log(f"Viimase laadimise 3-tunniseid ajaaknaid: {window_rows}.")
        log("Transformatsioon valmis.")
    finally:
        conn.close()


def run_quality_tests() -> None:
    conn = get_connection()
    try:
        execute_sql_file(conn, QUALITY_SQL)
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT test_name, status, failed_rows, message
                FROM quality.test_results
                ORDER BY test_name
                """
            )
            results = cur.fetchall()

        log("Andmekvaliteedi testid:")
        for test_name, status, failed_rows, message in results:
            log(f"- {test_name}: {status} ({failed_rows} vigast rida) - {message}")

        failed = [row for row in results if row[1] == "failed"]
        if failed:
            raise UserFacingError("Vähemalt üks andmekvaliteedi test ebaõnnestus.")
    finally:
        conn.close()


def print_query(conn, title: str, query: str) -> None:
    print()
    print(title)
    print("-" * len(title))
    with conn.cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()
        columns = [desc[0] for desc in cur.description]

    if not rows:
        print("Ridu ei ole.")
        return

    print(" | ".join(columns))
    for row in rows:
        print(" | ".join("" if value is None else str(value) for value in row))


def check_results() -> None:
    conn = get_connection()
    try:
        print_query(
            conn,
            "Viimased laadimised",
            """
            SELECT
                run_id,
                fetched_at,
                source_name,
                datetime_from,
                datetime_to,
                status,
                message
            FROM staging.pipeline_runs
            ORDER BY fetched_at DESC
            LIMIT 5
            """,
        )
        print_query(
            conn,
            "Aktiivsed sensorid",
            """
             SELECT
                sensor_id,
                parameter_name,
                location_id,
                unit
            FROM mart.dim_sensor
            ORDER BY sensor_id
            """,
        )
        print_query(
            conn,
            "Aktiivsed asukohad",
            """
            SELECT
                location_id,
                location_name,
                latitude,
                longitude,
                country_code,
                timezone
            FROM mart.dim_location
            ORDER BY location_name
            """,
        )
        #print_query(
            #conn,
            #"Parimad 3-tunnised ajaaknad",
            #"""
            #SELECT
                #location_name,
                #window_start,
                #window_end,
                #avg_combined_score,
                #avg_temperature_c,
                #total_precipitation_mm,
                #max_precipitation_probability_pct,
                #max_wind_speed_ms,
                #recommendation_label,
                #main_reason
            #FROM mart.latest_outdoor_activity_windows
            #ORDER BY avg_combined_score DESC, window_start
            #LIMIT 10
            #""",
        #)
        print_query(
            conn,
            "Andmekvaliteedi testid",
            """
            SELECT
                test_name,
                status,
                failed_rows,
                message
            FROM quality.test_results
            ORDER BY test_name
            """,
        )
    finally:
        conn.close()


def reset_data() -> None:
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                TRUNCATE TABLE
                    staging.parameter_values_raw,
                    staging.pipeline_runs,
                    quality.test_results
                CASCADE
                """
            )
        conn.commit()

        log("Staging ja quality tabelid on tühjendatud.")
    finally:
        conn.close()


def run_all() -> None:
    ingest()
    transform()
    run_quality_tests()
    log("Kogu töövoog õnnestus.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Õhukvaliteedi andmete töövoog.")
    parser.add_argument(
        "command",
        choices=["ingest", "transform", "test", "check", "reset", "run-all"],
        help="Töövoo samm, mida käivitada.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "ingest":
            ingest()
        elif args.command == "transform":
            transform()
        elif args.command == "test":
            run_quality_tests()
        elif args.command == "check":
            check_results()
        elif args.command == "reset":
            reset_data()
        elif args.command == "run-all":
            run_all()
        return 0
    except UserFacingError as exc:
        print(f"Viga: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
