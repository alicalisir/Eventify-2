"""
Google Events Scraper
=====================
Scrapes Google Events for a list of Turkish cities and upserts results
into the Supabase `events` table.

Usage (standalone test):
    cd backend/api
    python event_scraper.py           # scrape all configured cities
    python event_scraper.py istanbul  # scrape single city
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import time
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from bs4 import BeautifulSoup
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("caers.scraper")

SUPABASE_URL = os.environ["SUPABASE_URL"].strip()
SUPABASE_KEY = (os.environ.get("SUPABASE_SERVICE_KEY") or os.environ["SUPABASE_ANON_KEY"]).strip()
GOOGLE_PLACES_KEY = os.environ.get("GOOGLE_PLACES_API_KEY", "")

_SUPA_HEADERS = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates,return=minimal",
}


def _make_external_id(title: str, city: str, starts_at: Optional[str]) -> str:
    key = f"{title.lower().strip()}|{city.lower()}|{starts_at or ''}"
    return hashlib.sha1(key.encode()).hexdigest()

SCRAPER_CITIES: list[str] = [
    c.strip() for c in os.environ.get(
        "SCRAPER_CITIES", "Istanbul,Ankara,Izmir,Bursa,Antalya,Kocaeli"
    ).split(",") if c.strip()
]

_BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# Valid DB categories: music, sports, culture, food, outdoor, workshop, family
_CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "music":    ["concert", "gig", "festival", "jazz", "rock", "pop", "live music",
                 "band", "dj set", "dj", "hip hop", "electronic", "classical music"],
    "sports":   ["football", "basketball", "match", "tournament", "race", "marathon",
                 "tennis", "volleyball", "boxing", "wrestling", "cycling race"],
    "culture":  ["theater", "theatre", "play", "opera", "ballet", "exhibition", "gallery",
                 "museum", "art", "dance", "performance", "comedy", "stand-up",
                 "film", "cinema", "screening", "puppet", "circus"],
    "food":     ["food", "tasting", "gastronomy", "dinner", "brunch", "wine",
                 "beer", "cocktail", "chef", "culinary"],
    "outdoor":  ["hiking", "cycling", "trail", "park", "nature", "outdoor", "run",
                 "walk", "trekking", "kayak", "climbing"],
    "workshop": ["meetup", "workshop", "seminar", "conference", "fair", "talk",
                 "summit", "hackathon", "webinar", "training", "course"],
    "family":   ["family", "kids", "children", "circus", "puppet", "fairy tale"],
}

# Venue name patterns that strongly indicate a category
_VENUE_CATEGORY_HINTS: dict[str, list[str]] = {
    "music":   ["arena", "concert hall", "amphitheater", "amphitheatre", "pavilion",
                "blind", "babylon", "jolly joker", "suada", "zorlu psm"],
    "culture": ["performing arts", "theatre", "theater", "opera", "museum", "gallery",
                "cultural center", "cultural centre", "art center"],
    "sports":  ["stadium", "sports hall", "velodrome", "arena", "sports center"],
    "food":    ["restaurant", "bistro", "brasserie"],
}


def _classify_category(title: str, description: str = "", venue: str = "") -> str:
    text = (title + " " + description).lower()
    for category, keywords in _CATEGORY_KEYWORDS.items():
        if any(kw in text for kw in keywords):
            return category
    # Fall back to venue-name hints
    venue_lower = venue.lower()
    for category, hints in _VENUE_CATEGORY_HINTS.items():
        if any(h in venue_lower for h in hints):
            return category
    return "workshop"


def _geocode_address(address: str, city: str) -> tuple[Optional[float], Optional[float]]:
    if not GOOGLE_PLACES_KEY or not address:
        return None, None
    try:
        query = f"{address}, {city}, Turkey"
        with httpx.Client(timeout=5) as client:
            resp = client.get(
                "https://maps.googleapis.com/maps/api/geocode/json",
                params={"address": query, "key": GOOGLE_PLACES_KEY},
            )
        data = resp.json()
        if data.get("status") == "OK" and data.get("results"):
            loc = data["results"][0]["geometry"]["location"]
            return float(loc["lat"]), float(loc["lng"])
    except Exception as e:
        logger.debug("Geocoding failed for %r: %s", address, e)
    return None, None


_DAY_ABBREVS = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}
_MONTH_ABBREVS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}


def _parse_event_datetime(date_str: str) -> tuple[Optional[str], Optional[str]]:
    """Parse Google Events date strings into (starts_at_iso, ends_at_iso).

    Handles formats like:
      "Sat, 19:00 - 23:00"   "Today, 20:30 - 23:30"
      "Tomorrow, 18:00"       "Jun 15, 19:00 - 22:00"
    """
    if not date_str:
        return None, None

    now = datetime.now(timezone.utc)

    # Normalize en/em dashes to hyphen
    date_str = date_str.replace("–", "-").replace("—", "-").strip()

    # Extract time range "19:00 - 23:00" or single "19:00"
    time_range = re.search(r"(\d{1,2}:\d{2})\s*[-]\s*(\d{1,2}:\d{2})", date_str)
    single_time = re.search(r"(\d{1,2}:\d{2})", date_str)

    start_time_str = time_range.group(1) if time_range else (single_time.group(1) if single_time else None)
    end_time_str = time_range.group(2) if time_range else None

    lower = date_str.lower()
    base_date = None

    if lower.startswith("today"):
        base_date = now.date()
    elif lower.startswith("tomorrow"):
        base_date = (now + timedelta(days=1)).date()
    else:
        # Try "Jun 15" style
        month_day = re.search(r"([a-zA-Z]{3,9})\s+(\d{1,2})", lower)
        if month_day:
            month_str = month_day.group(1)[:3]
            day_num = int(month_day.group(2))
            month_num = _MONTH_ABBREVS.get(month_str)
            if month_num:
                year = now.year
                candidate = datetime(year, month_num, day_num, tzinfo=timezone.utc)
                if candidate.date() < now.date():
                    year += 1
                base_date = datetime(year, month_num, day_num, tzinfo=timezone.utc).date()
        else:
            # Try weekday abbreviation "Sat", "Mon", etc.
            day_match = re.search(r"\b([a-zA-Z]{3})\b", lower)
            if day_match:
                target_wd = _DAY_ABBREVS.get(day_match.group(1))
                if target_wd is not None:
                    delta = (target_wd - now.weekday()) % 7
                    if delta == 0:
                        delta = 7
                    base_date = (now + timedelta(days=delta)).date()

    if not base_date or not start_time_str:
        return None, None

    try:
        sh, sm = map(int, start_time_str.split(":"))
        starts_at = datetime(base_date.year, base_date.month, base_date.day,
                             sh, sm, tzinfo=timezone.utc).isoformat()
    except Exception:
        return None, None

    ends_at = None
    if end_time_str:
        try:
            eh, em = map(int, end_time_str.split(":"))
            ends_base = base_date
            if eh < sh or (eh == sh and em < sm):  # crosses midnight
                ends_base = (datetime(*base_date.timetuple()[:3], tzinfo=timezone.utc)
                             + timedelta(days=1)).date()
            ends_at = datetime(ends_base.year, ends_base.month, ends_base.day,
                               eh, em, tzinfo=timezone.utc).isoformat()
        except Exception:
            pass

    return starts_at, ends_at


def _parse_google_events(html: str, city: str) -> list[dict]:
    soup = BeautifulSoup(html, "html.parser")
    events = []

    # Strategy 1: JSON-LD structured data (most stable)
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or "")
            items = data if isinstance(data, list) else [data]
            for item in items:
                if item.get("@type") in ("Event", "MusicEvent", "SportsEvent"):
                    loc = item.get("location", {})
                    venue = loc.get("name", "") if isinstance(loc, dict) else str(loc)
                    address = ""
                    if isinstance(loc, dict) and isinstance(loc.get("address"), dict):
                        address = loc["address"].get("streetAddress", "")
                    start_str = item.get("startDate", "")
                    end_str = item.get("endDate", "")
                    try:
                        starts_at = datetime.fromisoformat(start_str.replace("Z", "+00:00")) if start_str else None
                    except Exception:
                        starts_at = None
                    try:
                        ends_at = datetime.fromisoformat(end_str.replace("Z", "+00:00")) if end_str else None
                    except Exception:
                        ends_at = None
                    title = item.get("name", "").strip()
                    if not title:
                        continue
                    desc = item.get("description", "")
                    category = _classify_category(title, desc, venue)
                    events.append({
                        "title": title,
                        "description": desc[:500] if desc else None,
                        "category": category,
                        "venue_name": venue or None,
                        "address": address or None,
                        "city": city,
                        "starts_at": starts_at.isoformat() if starts_at else None,
                        "ends_at": ends_at.isoformat() if ends_at else None,
                    })
        except Exception:
            continue

    if events:
        return events

    # Strategy 2: Google Events HTML (PaEvOc containers — observed structure)
    # Title: class "YOGjf"
    # Date/time: class "cEZxRc" (without "zvDXNd")
    # Venue + address: class "cEZxRc zvDXNd" first element
    # City/district:  class "cEZxRc zvDXNd" second element
    containers = soup.find_all("div", class_="PaEvOc")
    for container in containers[:25]:
        title_el = container.find(class_="YOGjf")
        if not title_el:
            continue
        title = title_el.get_text(strip=True)
        if len(title) < 3:
            continue

        all_cezxrc = container.find_all(class_="cEZxRc")
        zvd_els = [el for el in all_cezxrc if "zvDXNd" in (el.get("class") or [])]
        non_zvd_els = [el for el in all_cezxrc if "zvDXNd" not in (el.get("class") or [])]

        date_str = non_zvd_els[0].get_text(strip=True) if non_zvd_els else ""
        venue_addr = zvd_els[0].get_text(strip=True) if zvd_els else ""
        city_district = zvd_els[1].get_text(strip=True) if len(zvd_els) > 1 else ""

        # Split "Venue Name, Street Address" on first comma
        venue_name = ""
        street_address = ""
        if "," in venue_addr:
            parts = venue_addr.split(",", 1)
            venue_name = parts[0].strip()
            street_address = parts[1].strip()
        else:
            venue_name = venue_addr

        # Full address string for geocoding
        full_address = venue_addr
        if city_district and city_district not in full_address:
            full_address = f"{full_address}, {city_district}"

        starts_at_iso, ends_at_iso = _parse_event_datetime(date_str)
        category = _classify_category(title, "", venue_name)

        events.append({
            "title": title,
            "description": None,
            "category": category,
            "venue_name": venue_name or None,
            "address": street_address or (venue_addr or None),
            "city": city,
            "starts_at": starts_at_iso,
            "ends_at": ends_at_iso,
            "_geocode_addr": full_address,  # removed before upsert
        })

    # Strategy 3: older Google HTML fallback
    if not events:
        for container in soup.select("div[data-eventid], g-card.TBGc5c")[:20]:
            title_el = container.find(["h3", "span", "div"],
                                      class_=re.compile(r"YOGjf|vlA7Fb|rZwiVb"))
            if not title_el:
                spans = container.find_all("span", string=True)
                title_el = next((s for s in spans if len(s.get_text(strip=True)) > 5), None)
            if not title_el:
                continue
            title = title_el.get_text(strip=True)
            if len(title) < 3:
                continue
            events.append({
                "title": title,
                "description": None,
                "category": _classify_category(title),
                "venue_name": None,
                "address": None,
                "city": city,
                "starts_at": None,
                "ends_at": None,
            })

    return events


def scrape_city(city: str) -> list[dict]:
    url = "https://www.google.com/search"
    params = {
        "q": f"events in {city}",
        "ibp": "htl;events",
        "hl": "en",
        "gl": "tr",
    }
    try:
        with httpx.Client(timeout=15, headers=_BROWSER_HEADERS, follow_redirects=True) as client:
            resp = client.get(url, params=params)
        if resp.status_code != 200:
            logger.warning("[scraper] %s HTTP %s", city, resp.status_code)
            return []
        raw = _parse_google_events(resp.text, city)
    except Exception as e:
        logger.warning("[scraper] %s request failed: %s", city, e)
        return []

    enriched = []
    for ev in raw:
        geocode_addr = ev.pop("_geocode_addr", None) or ev.get("address") or ev.get("venue_name") or ""
        lat, lng = _geocode_address(geocode_addr, city)
        if lat:
            ev["lat"] = lat
            ev["lng"] = lng
        enriched.append(ev)
        time.sleep(0.2)

    logger.info("[scraper] %s -> %d events", city, len(enriched))
    return enriched


def upsert_events(events: list[dict]) -> int:
    if not events:
        return 0
    now = datetime.now(timezone.utc).isoformat()
    rows = []
    for ev in events:
        title = ev["title"]
        city = ev.get("city", "")
        starts_at = ev.get("starts_at")
        rows.append({
            "source": "scraped",
            "external_id": _make_external_id(title, city, starts_at),
            "title": title,
            "description": ev.get("description"),
            "category": ev.get("category", "workshop"),
            "venue_name": ev.get("venue_name"),
            "address": ev.get("address"),
            "city": city,
            "lat": ev.get("lat"),
            "lng": ev.get("lng"),
            "starts_at": starts_at,
            "ends_at": ev.get("ends_at"),
            "is_ticketed": False,
            "language": "en",
            "updated_at": now,
        })
    try:
        with httpx.Client(timeout=15) as client:
            resp = client.post(
                f"{SUPABASE_URL}/rest/v1/events",
                params={"on_conflict": "external_id"},
                headers=_SUPA_HEADERS,
                json=rows,
            )
        if resp.status_code in (200, 201):
            logger.info("[scraper] upserted %d rows", len(rows))
            return len(rows)
        logger.warning("[scraper] upsert status=%s body=%s", resp.status_code, resp.text[:200])
        return 0
    except Exception as e:
        logger.warning("[scraper] upsert failed: %s", e)
        return 0


def scrape_all_cities() -> None:
    logger.info("[scraper] starting cycle for cities: %s", SCRAPER_CITIES)
    total = 0
    for city in SCRAPER_CITIES:
        events = scrape_city(city)
        total += upsert_events(events)
        time.sleep(1.0)
    logger.info("[scraper] cycle complete -- %d events upserted", total)


if __name__ == "__main__":
    import sys
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s | %(message)s")
    cities = sys.argv[1:] if len(sys.argv) > 1 else SCRAPER_CITIES
    for city in cities:
        evs = scrape_city(city)
        print(f"{city}: {len(evs)} events")
        for e in evs[:5]:
            print(f"  - {e['title']} | {e.get('category')} | {e.get('venue_name')} | "
                  f"{e.get('starts_at')} | lat={e.get('lat')}")
        upsert_events(evs)
