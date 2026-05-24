import requests
import json
import os

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

print(json.dumps(response.json(), indent=2))