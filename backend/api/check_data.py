import httpx, os
from dotenv import load_dotenv
load_dotenv()

url = os.environ["SUPABASE_URL"]
key = os.environ["SUPABASE_ANON_KEY"]
headers = {
    "apikey": key,
    "Authorization": "Bearer " + key,
    "Prefer": "count=exact",
}

for table in ["gps_pings", "app_sessions", "screen_events"]:
    r = httpx.get(
        url + "/rest/v1/" + table,
        headers=headers,
        params={"select": "count"},
    )
    cr = r.headers.get("content-range", "0/0")
    total = cr.split("/")[-1] if "/" in cr else "?"
    print(table + ": " + total + " rows")
