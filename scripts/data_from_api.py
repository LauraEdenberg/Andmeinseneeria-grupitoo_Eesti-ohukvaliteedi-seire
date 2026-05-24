import requests
import json
import os
# Lokaalselt jooksutamiseks ja faili salvestamiseks konterineri väliselt
# from dotenv import load_dotenv
# load_dotenv()

url = "https://api.openaq.org/v3/sensors/35307/measurements"

params = {
    "datetime_from": "2026-05-01T00:00:00Z",
    "limit": 1000
}

api_key = os.getenv("OPENAQ_API_KEY")
if not api_key:
    raise ValueError("Missing OPENAQ_API_KEY in environment")

headers = {"X-API-Key": api_key}

response = requests.get(url, headers=headers, params=params)

if response.status_code != 200:
    raise Exception(f"API error {response.status_code}: {response.text}")

data = response.json()

# from datetime import datetime, timezone

# timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
# filename = f"openaq_{timestamp}.json"

# with open(filename, "w", encoding="utf-8") as f:
#     json.dump(data, f, indent=2)

print(json.dumps(data, indent=2))