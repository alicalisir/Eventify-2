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

import json
import logging
import os
import re
import time
from datetime import datetime, timezone
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
    "music":    ["concert", "gig", "festival", "jazz", "rock", "pop", "live music", "müzik", "konser"],
    "sports":   ["football", "basketball", "match", "tournament", "race", "marathon", "spor", "maç"],
    "culture":  ["theater", "theatre", "play", "opera", "ballet", "exhibition", "gallery", "museum",
                 "art", "tiyatro", "sahne", "sergisi", "sanat"],
    "food":     ["food", "tasting", "market", "yemek", "pazar", "gastronomy"],
    "outdoor":  ["hiking", "cycling", "trail", "park", "nature", "outdoor", "yürüyüş"],
    "workshop": ["meetup", "workshop", "seminar", "conference", "fair", "toplantı", "etkinlik"],
    "family":   ["family", "kids", "children", "aile", "çocuk"],
}


def _classify_category(title: str, description: str = "") -> str:
    text = (title + " " + description).lower()
    for category, keywords in _CATEGORY_KEYWORDS.items():
        if any(kw in text for kw in keywords):
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
                    category = _classify_category(title, desc)
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

    # Strategy 2: hCard / data-event divs (Google Events list HTML)
    containers = soup.select("div[data-eventid], div.PaEvOc, g-card.TBGc5c")
    for container in containers[:20]:
        title_el = container.find(["h3", "span", "div"], class_=re.compile(r"YOGjf|vlA7Fb|rZwiVb"))
        if not title_el:
            # Grab the first text-heavy span
            spans = container.find_all("span", string=True)
            title_el = next((s for s in spans if len(s.get_text(strip=True)) > 5), None)
        if not title_el:
            continue
        title = title_el.get_text(strip=True)
        if len(title) < 3:
            continue

        date_el = container.find(class_=re.compile(r"Gkoz7b|cuvxDd|xXEKkb"))
        date_str = date_el.get_text(strip=True) if date_el else ""

        venue_el = container.find(class_=re.compile(r"cXIK1b|Fwcmle|vynOhf"))
        venue = venue_el.get_text(strip=True) if venue_el else ""

        category = _classify_category(title)
        events.append({
            "title": title,
            "description": None,
            "category": category,
            "venue_name": venue or None,
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

    # Geocode venues that have an address
    enriched = []
    for ev in raw:
        addr = ev.get("address") or ev.get("venue_name") or ""
        lat, lng = _geocode_address(addr, city)
        if lat:
            ev["lat"] = lat
            ev["lng"] = lng
        enriched.append(ev)
        time.sleep(0.2)  # be polite to geocoding API

    logger.info("[scraper] %s -> %d events", city, len(enriched))
    return enriched


def upsert_events(events: list[dict]) -> int:
    if not events:
        return 0
    now = datetime.now(timezone.utc).isoformat()
    rows = []
    for ev in events:
        rows.append({
            "source": "scraped",
            "title": ev["title"],
            "description": ev.get("description"),
            "category": ev.get("category", "community"),
            "venue_name": ev.get("venue_name"),
            "address": ev.get("address"),
            "city": ev.get("city"),
            "lat": ev.get("lat"),
            "lng": ev.get("lng"),
            "starts_at": ev.get("starts_at"),
            "ends_at": ev.get("ends_at"),
            "is_ticketed": False,
            "language": "en",
            "updated_at": now,
        })
    try:
        with httpx.Client(timeout=15) as client:
            resp = client.post(
                f"{SUPABASE_URL}/rest/v1/events",
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
    logger.info("[scraper] cycle complete — %d events upserted", total)


if __name__ == "__main__":
    import sys
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s | %(message)s")
    cities = sys.argv[1:] if len(sys.argv) > 1 else SCRAPER_CITIES
    for city in cities:
        evs = scrape_city(city)
        print(f"{city}: {len(evs)} events")
        for e in evs[:3]:
            print(f"  - {e['title']} | {e.get('category')} | {e.get('venue_name')}")
        upsert_events(evs)
