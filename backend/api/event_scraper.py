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
TICKETMASTER_API_KEY = os.environ.get("TICKETMASTER_API_KEY", "")

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

# Valid DB categories
_CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "music":    ["concert", "gig", "festival", "jazz", "rock", "pop", "live music",
                 "band", "dj set", "dj", "hip hop", "electronic", "classical music",
                 "techno", "house", "indie", "r&b", "soul"],
    "sports":   ["football", "basketball", "match", "tournament", "race", "marathon",
                 "tennis", "volleyball", "boxing", "wrestling", "cycling race", "fitness"],
    "culture":  ["theater", "theatre", "play", "opera", "ballet", "exhibition", "gallery",
                 "museum", "art", "dance", "performance", "comedy", "stand-up",
                 "film", "cinema", "screening", "puppet", "circus"],
    "food":     ["food", "tasting", "gastronomy", "dinner", "brunch", "wine",
                 "beer", "cocktail", "chef", "culinary", "degustasyon"],
    "outdoor":  ["hiking", "cycling", "trail", "park", "nature", "outdoor", "run",
                 "walk", "trekking", "kayak", "climbing"],
    "workshop": ["meetup", "workshop", "seminar", "conference", "fair", "talk",
                 "summit", "hackathon", "webinar", "training", "course"],
    "family":   ["family", "kids", "children", "circus", "puppet", "fairy tale"],
}

_VENUE_CATEGORY_HINTS: dict[str, list[str]] = {
    # Concert/music venues — checked first
    "music":   ["arena", "concert hall", "amphitheater", "amphitheatre", "pavilion",
                "blind", "babylon", "jolly joker", "suada", "zorlu", "uniq",
                "maksimum", "maximum", "volkswagen arena", "turkcell", "if performance",
                "performing arts", "stadium", "jj arena", "hall beşiktaş"],
    "culture": ["theatre", "theater", "opera", "museum", "gallery",
                "cultural center", "cultural centre", "art center", "bomontiada"],
    "sports":  ["sports hall", "velodrome", "sports center", "arena spor"],
    "food":    ["bistro", "brasserie"],  # "restaurant" removed — too many concert venues are restaurants
}

# Ticket-platform domains that strongly indicate a music event
_MUSIC_TICKET_DOMAINS = {
    "spotify.com", "songkick.com", "concertflow.com",
    "setlist.fm", "bandsintown.com", "viagogo",
}

# More specific subcategory within each category
_SUBCATEGORY_KEYWORDS: dict[str, list[str]] = {
    "concert":       ["concert", "gig", "live music", "live show"],
    "festival":      ["festival", "fest"],
    "dj-night":      ["dj set", "dj", "techno", "house", "electronic", "nightclub"],
    "open-air":      ["open air", "outdoor concert", "amphitheater", "amphitheatre"],
    "stand-up":      ["stand-up", "comedy show", "comedy night"],
    "theater":       ["theater", "theatre", "play", "tiyatro"],
    "ballet-opera":  ["opera", "ballet", "bale"],
    "exhibition":    ["exhibition", "gallery", "sergi", "expo"],
    "film":          ["film", "cinema", "screening", "movie"],
    "sports-match":  ["match", "tournament", "championship"],
    "marathon-run":  ["marathon", "half marathon", "run", "race"],
    "food-tasting":  ["tasting", "wine tasting", "beer tasting", "degustasyon"],
    "brunch":        ["brunch", "breakfast event"],
    "workshop":      ["workshop", "atölye", "craft"],
    "conference":    ["conference", "summit", "seminar"],
    "hackathon":     ["hackathon"],
}

# Domains that are ticket sales platforms (used to detect ticket_url and is_ticketed)
_TICKET_DOMAINS = {
    "bilet.com", "biletix.com", "passo.com.tr", "biletmaster.com.tr",
    "ticketmaster.com", "eventbrite.com", "concertflow.com",
    "jollyjoker.net", "mobilet.com", "ticketmaster.com.tr",
}

# Domains to skip when looking for ticket_url (info/streaming, not ticketing)
_SKIP_DOMAINS = {"google.com", "spotify.com", "youtube.com", "facebook.com",
                 "instagram.com", "twitter.com", "wikipedia.org"}


def _make_external_id(title: str, city: str, starts_at: Optional[str]) -> str:
    key = f"{title.lower().strip()}|{city.lower()}|{starts_at or ''}"
    return hashlib.sha1(key.encode()).hexdigest()


def _classify_category(title: str, description: str = "", venue: str = "",
                        ticket_url: str = "", has_music_link: bool = False) -> str:
    text = (title + " " + description).lower()
    for category, keywords in _CATEGORY_KEYWORDS.items():
        if any(kw in text for kw in keywords):
            return category
    # Music platform link (Spotify concert, Songkick, etc.) → music
    if has_music_link:
        return "music"
    if ticket_url:
        m = re.search(r"://(?:www\.)?([^/]+)", ticket_url)
        if m and any(d in m.group(1) for d in _MUSIC_TICKET_DOMAINS):
            return "music"
    venue_lower = venue.lower()
    for category, hints in _VENUE_CATEGORY_HINTS.items():
        if any(h in venue_lower for h in hints):
            return category
    return "workshop"


def _get_subcategory(title: str, description: str = "", venue: str = "",
                     category: str = "") -> Optional[str]:
    text = (title + " " + description + " " + venue).lower()
    for sub, keywords in _SUBCATEGORY_KEYWORDS.items():
        if any(kw in text for kw in keywords):
            return sub
    # Default subcategory when category is known but no specific sub matched
    if category == "music":
        return "concert"
    if category == "sports":
        return "sports-match"
    return None


def _get_tags(title: str, category: str, subcategory: Optional[str],
              venue: str = "") -> list[str]:
    tags: list[str] = []
    text = (title + " " + venue).lower()
    # Always include category
    if category:
        tags.append(category)
    if subcategory and subcategory != category:
        tags.append(subcategory)
    # Music genre hints
    for genre in ["jazz", "rock", "pop", "hip hop", "electronic", "techno",
                  "house", "indie", "classical", "r&b", "soul"]:
        if genre in text:
            tags.append(genre)
    # Venue type hints
    for vt in ["open air", "outdoor", "rooftop", "club", "festival"]:
        if vt in text:
            tags.append(vt)
    return list(dict.fromkeys(tags))[:6]  # deduplicate, max 6


def _extract_links(container) -> tuple[Optional[str], bool]:
    """Return (ticket_url, has_music_platform_link).

    ticket_url  — first ticketing-platform URL (Spotify excluded).
    has_music_platform_link — True if any Spotify/Songkick/etc. link exists,
                              used as a music category signal even when no
                              ticket URL is available.
    """
    links = [a["href"] for a in container.find_all("a", href=True)
             if a["href"].startswith("http")]
    ticket_url: Optional[str] = None
    fallback_url: Optional[str] = None
    has_music = False

    for url in links:
        m = re.search(r"://(?:www\.)?([^/]+)", url)
        if not m:
            continue
        domain = m.group(1)
        if any(d in domain for d in _MUSIC_TICKET_DOMAINS) or "spotify.com" in domain:
            has_music = True
        if any(d in domain for d in _SKIP_DOMAINS):
            continue
        if any(d in domain for d in _TICKET_DOMAINS):
            ticket_url = url
            break
        if fallback_url is None:
            fallback_url = url

    return ticket_url or fallback_url, has_music


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


def _resolve_month_day(month_str: str, day_num: int,
                       now: datetime) -> Optional[datetime.date]:
    month_num = _MONTH_ABBREVS.get(month_str[:3].lower())
    if not month_num:
        return None
    year = now.year
    candidate = datetime(year, month_num, day_num, tzinfo=timezone.utc)
    if candidate.date() < now.date():
        year += 1
    return datetime(year, month_num, day_num, tzinfo=timezone.utc).date()


def _parse_event_datetime(date_str: str) -> tuple[Optional[str], Optional[str]]:
    """Parse Google Events date strings → (starts_at_iso, ends_at_iso).

    Handles:
      "Sat, 19:00 – 23:00"        single-day with time range
      "Today, 20:30 – 23:30"      relative single-day
      "Tomorrow, 18:00"           single time
      "Jun 15, 19:00 – 22:00"     month-day with time
      "Sat, Jun 6 – Sun, Jun 7"   multi-day range (no time) → 00:00 / 23:59
      "Jun 6 – Jun 8"             multi-day range (no time)
    """
    if not date_str:
        return None, None

    now = datetime.now(timezone.utc)
    s = date_str.replace("–", "-").replace("—", "-").strip()
    lower = s.lower()

    # ── 1. Time range present: "19:00 - 23:00" ──────────────────────────────
    time_range = re.search(r"(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})", s)
    single_time = re.search(r"(\d{1,2}:\d{2})", s)

    start_time_str = time_range.group(1) if time_range else (
        single_time.group(1) if single_time else None
    )
    end_time_str = time_range.group(2) if time_range else None

    # ── 2. Resolve base_date for the start ──────────────────────────────────
    base_date = None

    if lower.startswith("today"):
        base_date = now.date()
    elif lower.startswith("tomorrow"):
        base_date = (now + timedelta(days=1)).date()
    else:
        # "Jun 15" or "Sat, Jun 6" style — take the first month-day found
        month_day = re.search(r"\b([a-zA-Z]{3,9})\s+(\d{1,2})\b", lower)
        if month_day:
            base_date = _resolve_month_day(month_day.group(1), int(month_day.group(2)), now)
        else:
            # Bare weekday: "Sat", "Mon"
            day_match = re.search(r"\b([a-zA-Z]{3})\b", lower)
            if day_match:
                target_wd = _DAY_ABBREVS.get(day_match.group(1))
                if target_wd is not None:
                    delta = (target_wd - now.weekday()) % 7 or 7
                    base_date = (now + timedelta(days=delta)).date()

    if base_date is None:
        return None, None

    # ── 3. Multi-day range with no time: "Jun 6 - Jun 7" or "Sat, Jun 6 - Sun, Jun 7" ──
    if start_time_str is None:
        # Try to parse an end date from the second half after " - "
        end_date = None
        parts = re.split(r"\s+-\s+", lower, maxsplit=1)
        if len(parts) == 2:
            end_md = re.search(r"\b([a-zA-Z]{3,9})\s+(\d{1,2})\b", parts[1])
            if end_md:
                end_date = _resolve_month_day(end_md.group(1), int(end_md.group(2)), now)
            else:
                end_day = re.search(r"\b([a-zA-Z]{3})\b", parts[1])
                if end_day:
                    target_wd = _DAY_ABBREVS.get(end_day.group(1))
                    if target_wd is not None:
                        delta = (target_wd - now.weekday()) % 7 or 7
                        end_date = (now + timedelta(days=delta)).date()

        starts_at = datetime(base_date.year, base_date.month, base_date.day,
                             0, 0, tzinfo=timezone.utc).isoformat()
        if end_date:
            ends_at = datetime(end_date.year, end_date.month, end_date.day,
                               23, 59, tzinfo=timezone.utc).isoformat()
        else:
            ends_at = datetime(base_date.year, base_date.month, base_date.day,
                               23, 59, tzinfo=timezone.utc).isoformat()
        return starts_at, ends_at

    # ── 4. Single-day with time ──────────────────────────────────────────────
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

    # Strategy 1: JSON-LD structured data (most stable when present)
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or "")
            items = data if isinstance(data, list) else [data]
            for item in items:
                if item.get("@type") not in ("Event", "MusicEvent", "SportsEvent"):
                    continue
                loc = item.get("location", {})
                venue = loc.get("name", "") if isinstance(loc, dict) else str(loc)
                address = ""
                if isinstance(loc, dict) and isinstance(loc.get("address"), dict):
                    address = loc["address"].get("streetAddress", "")
                start_str = item.get("startDate", "")
                end_str = item.get("endDate", "")
                try:
                    starts_at = datetime.fromisoformat(
                        start_str.replace("Z", "+00:00")) if start_str else None
                except Exception:
                    starts_at = None
                try:
                    ends_at = datetime.fromisoformat(
                        end_str.replace("Z", "+00:00")) if end_str else None
                except Exception:
                    ends_at = None
                title = item.get("name", "").strip()
                if not title:
                    continue
                desc = item.get("description", "")
                ticket_url_ld = (item.get("offers") or {}).get("url", "") if isinstance(item.get("offers"), dict) else ""
                category    = _classify_category(title, desc, venue, ticket_url_ld)
                subcategory = _get_subcategory(title, desc, venue, category)
                offers = item.get("offers", {})
                price_min = price_max = None
                ticket_url = None
                if isinstance(offers, dict):
                    try:
                        price_min = price_max = float(offers.get("price", 0)) or None
                    except Exception:
                        pass
                    ticket_url = offers.get("url")
                events.append({
                    "title": title,
                    "description": desc[:500] if desc else None,
                    "category": category,
                    "subcategory": subcategory,
                    "venue_name": venue or None,
                    "address": address or None,
                    "city": city,
                    "starts_at": starts_at.isoformat() if starts_at else None,
                    "ends_at": ends_at.isoformat() if ends_at else None,
                    "ticket_url": ticket_url,
                    "price_min": price_min,
                    "price_max": price_max,
                    "is_ticketed": bool(ticket_url or price_min),
                    "tags": _get_tags(title, category, subcategory, venue),
                })
        except Exception:
            continue

    if events:
        return events

    # Strategy 2: Google Events HTML — use li.PaEvOc as the full container
    # (li holds both the content div and the external links)
    # Title:   class "YOGjf"
    # Date:    class "cEZxRc" without "zvDXNd"
    # Venue:   class "cEZxRc zvDXNd" [0]
    # District:class "cEZxRc zvDXNd" [1]
    li_containers = soup.find_all("li", class_="PaEvOc")
    for container in li_containers[:25]:
        title_el = container.find(class_="YOGjf")
        if not title_el:
            continue
        title = title_el.get_text(strip=True)
        if len(title) < 3:
            continue

        all_cezxrc = container.find_all(class_="cEZxRc")
        zvd_els     = [el for el in all_cezxrc if "zvDXNd" in (el.get("class") or [])]
        non_zvd_els = [el for el in all_cezxrc if "zvDXNd" not in (el.get("class") or [])]

        date_str     = non_zvd_els[0].get_text(strip=True) if non_zvd_els else ""
        venue_addr   = zvd_els[0].get_text(strip=True) if zvd_els else ""
        city_district= zvd_els[1].get_text(strip=True) if len(zvd_els) > 1 else ""

        if "," in venue_addr:
            parts        = venue_addr.split(",", 1)
            venue_name   = parts[0].strip()
            street_addr  = parts[1].strip()
        else:
            venue_name   = venue_addr
            street_addr  = ""

        full_address = venue_addr
        if city_district and city_district not in full_address:
            full_address = f"{full_address}, {city_district}"

        starts_at_iso, ends_at_iso = _parse_event_datetime(date_str)
        ticket_url, has_music_link = _extract_links(container)
        category    = _classify_category(title, "", venue_name, ticket_url or "", has_music_link)
        subcategory = _get_subcategory(title, "", venue_name, category)

        events.append({
            "title": title,
            "description": None,
            "category": category,
            "subcategory": subcategory,
            "venue_name": venue_name or None,
            "address": street_addr or (venue_addr or None),
            "city": city,
            "starts_at": starts_at_iso,
            "ends_at": ends_at_iso,
            "ticket_url": ticket_url,
            "price_min": None,
            "price_max": None,
            "is_ticketed": ticket_url is not None,
            "tags": _get_tags(title, category, subcategory, venue_name),
            "_geocode_addr": full_address,
        })

    if not events:
        logger.warning("[scraper] %s — no structured event data found (datacenter IP?)", city)

    return events


def scrape_city(city: str) -> list[dict]:
    url = "https://www.google.com/search"
    params = {"q": f"events in {city}", "ibp": "htl;events", "hl": "en", "gl": "tr"}
    try:
        with httpx.Client(timeout=15, headers=_BROWSER_HEADERS,
                          follow_redirects=True) as client:
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
        geocode_addr = (ev.pop("_geocode_addr", None)
                        or ev.get("address") or ev.get("venue_name") or "")
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
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    rows = []
    for ev in events:
        title     = ev["title"]
        city      = ev.get("city", "")
        starts_at = ev.get("starts_at")
        ends_at   = ev.get("ends_at")

        # Use pre-computed expires_at if provided, otherwise derive it
        expires_at = ev.get("expires_at")
        if not expires_at:
            if ends_at:
                expires_at = ends_at
            elif starts_at:
                try:
                    st = datetime.fromisoformat(starts_at.replace("Z", "+00:00"))
                    expires_at = (st + timedelta(hours=8)).isoformat()
                except Exception:
                    expires_at = None

        ticket_url = ev.get("ticket_url")
        rows.append({
            "source":           ev.get("source", "scraped"),
            "external_id":      ev.get("external_id") or _make_external_id(title, city, starts_at),
            "title":            title,
            "description":      ev.get("description"),
            "category":         ev.get("category", "workshop"),
            "subcategory":      ev.get("subcategory"),
            "venue_name":       ev.get("venue_name"),
            "address":          ev.get("address"),
            "city":             city,
            "lat":              ev.get("lat"),
            "lng":              ev.get("lng"),
            "is_recurring":     ev.get("is_recurring", False),
            "starts_at":        starts_at,
            "ends_at":          ends_at,
            "is_ticketed":      ev.get("is_ticketed", bool(ticket_url or ev.get("price_min"))),
            "price_min":        ev.get("price_min"),
            "price_max":        ev.get("price_max"),
            "currency":         ev.get("currency", "TRY"),
            "ticket_url":       ticket_url,
            "image_url":        ev.get("image_url"),
            "tags":             ev.get("tags") or [],
            "language":         ev.get("language", "en"),
            "popularity_score": ev.get("popularity_score", 0.5 if ticket_url else 0.0),
            "expires_at":       expires_at,
            "updated_at":       now_iso,
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
        logger.warning("[scraper] upsert status=%s body=%s",
                       resp.status_code, resp.text[:200])
        return 0
    except Exception as e:
        logger.warning("[scraper] upsert failed: %s", e)
        return 0


# ─── Ticketmaster Discovery API ───────────────────────────────────────────────

_TM_BASE = "https://app.ticketmaster.com/discovery/v2/events.json"

_TM_SEGMENT_TO_CATEGORY: dict[str, str] = {
    "music":           "music",
    "sports":          "sports",
    "arts & theatre":  "culture",
    "film":            "culture",
    "family":          "family",
    "miscellaneous":   "workshop",
}

# Ticketmaster city name overrides (our name → TM query name)
_TM_CITY_MAP: dict[str, str] = {
    "Kocaeli": "Izmit",
    "Izmir":   "Izmir",
}


def _tm_parse_event(ev: dict) -> Optional[dict]:
    """Convert a Ticketmaster event dict into our DB row format."""
    title = ev.get("name", "").strip()
    if not title:
        return None

    tm_id = ev.get("id", "")

    # Dates
    dates = ev.get("dates", {})
    start = dates.get("start", {})
    starts_at: Optional[str] = start.get("dateTime")  # ISO with Z
    if not starts_at:
        local_date = start.get("localDate")
        local_time = start.get("localTime", "20:00:00")
        if local_date:
            starts_at = f"{local_date}T{local_time}+03:00"

    end = dates.get("end", {})
    ends_at: Optional[str] = end.get("dateTime")

    # expires_at: day after event ends (or starts if no end)
    expires_at: Optional[str] = None
    if ends_at:
        expires_at = ends_at
    elif starts_at:
        try:
            from datetime import datetime, timezone, timedelta
            dt = datetime.fromisoformat(starts_at.replace("Z", "+00:00"))
            expires_at = (dt + timedelta(hours=4)).isoformat()
        except Exception:
            pass

    # Venue
    venues = ev.get("_embedded", {}).get("venues", [])
    venue = venues[0] if venues else {}
    venue_name = venue.get("name", "")
    city_obj = venue.get("city", {})
    city = city_obj.get("name", "Istanbul")
    address_obj = venue.get("address", {})
    address = address_obj.get("line1", "")
    if venue.get("postalCode"):
        address = f"{address}, {venue.get('postalCode', '')}".strip(", ")

    # Category from Ticketmaster segment
    classifications = ev.get("classifications", [])
    segment_name = ""
    genre_name = ""
    if classifications:
        seg = classifications[0].get("segment", {})
        segment_name = seg.get("name", "").lower()
        gen = classifications[0].get("genre", {})
        genre_name = gen.get("name", "").lower()

    category = _TM_SEGMENT_TO_CATEGORY.get(segment_name)
    if not category:
        category = _classify_category(title, venue=venue_name)

    subcategory = _get_subcategory(title, venue=venue_name, category=category)
    if not subcategory and genre_name and genre_name not in ("undefined", "other"):
        subcategory = genre_name[:40]

    # Price
    price_ranges = ev.get("priceRanges", [])
    price_min: Optional[float] = None
    price_max: Optional[float] = None
    currency = "TRY"
    if price_ranges:
        pr = price_ranges[0]
        price_min = pr.get("min")
        price_max = pr.get("max")
        currency = pr.get("currency", "TRY")

    # Ticket URL
    ticket_url = ev.get("url", "")

    # Image
    images = ev.get("images", [])
    image_url: Optional[str] = None
    for img in images:
        if img.get("ratio") == "16_9" and img.get("width", 0) >= 640:
            image_url = img.get("url")
            break
    if not image_url and images:
        image_url = images[0].get("url")

    tags = [t for t in [segment_name, genre_name] if t and t not in ("undefined", "other")]

    now = datetime.now(timezone.utc)
    return {
        "source":           "ticketmaster",
        "external_id":      f"tm_{tm_id}",
        "title":            title,
        "description":      None,
        "category":         category,
        "subcategory":      subcategory,
        "venue_name":       venue_name or None,
        "address":          address or None,
        "city":             city,
        "is_recurring":     False,
        "is_ticketed":      True,
        "price_min":        price_min,
        "price_max":        price_max,
        "currency":         currency,
        "ticket_url":       ticket_url or None,
        "image_url":        image_url,
        "tags":             tags,
        "language":         "en",
        "popularity_score": 0.70,
        "starts_at":        starts_at,
        "ends_at":          ends_at,
        "expires_at":       expires_at,
        "updated_at":       now.isoformat(),
    }


def fetch_ticketmaster_city(city: str, page_size: int = 50) -> list[dict]:
    """Fetch upcoming events from Ticketmaster Discovery API for one city."""
    if not TICKETMASTER_API_KEY:
        return []

    tm_city = _TM_CITY_MAP.get(city, city)
    now = datetime.now(timezone.utc)
    start_dt = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    end_dt = (now + timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%SZ")

    params = {
        "apikey":       TICKETMASTER_API_KEY,
        "city":         tm_city,
        "countryCode":  "TR",
        "size":         str(page_size),
        "sort":         "date,asc",
        "startDateTime": start_dt,
        "endDateTime":   end_dt,
    }

    try:
        with httpx.Client(timeout=15) as client:
            r = client.get(_TM_BASE, params=params)
        if r.status_code != 200:
            logger.warning("[ticketmaster] %s status=%s", city, r.status_code)
            return []
        data = r.json()
        raw_events = data.get("_embedded", {}).get("events", [])
        logger.info("[ticketmaster] %s → %d raw events", city, len(raw_events))
        rows = []
        for ev in raw_events:
            row = _tm_parse_event(ev)
            if row:
                rows.append(row)
        return rows
    except Exception as e:
        logger.warning("[ticketmaster] fetch failed city=%s: %s", city, e)
        return []


def fetch_all_ticketmaster() -> None:
    """Fetch Ticketmaster events for all configured cities and upsert."""
    logger.info("[ticketmaster] starting cycle for cities: %s", SCRAPER_CITIES)
    total = 0
    for city in SCRAPER_CITIES:
        rows = fetch_ticketmaster_city(city)
        if rows:
            total += upsert_events(rows)
        time.sleep(0.5)
    logger.info("[ticketmaster] cycle complete — %d events upserted", total)


def scrape_all_cities() -> None:
    if TICKETMASTER_API_KEY:
        fetch_all_ticketmaster()
    else:
        logger.info("[scraper] no Ticketmaster key, falling back to Google scraper")
        logger.info("[scraper] starting cycle for cities: %s", SCRAPER_CITIES)
        total = 0
        for city in SCRAPER_CITIES:
            events = scrape_city(city)
            total += upsert_events(events)
            time.sleep(1.0)
        logger.info("[scraper] cycle complete -- %d events upserted", total)


# ─── Demo seed ────────────────────────────────────────────────────────────────
# Hard-coded recurring events inserted at startup when the DB is sparse.
# is_recurring=True means no starts_at required — they always surface in queries.

_DEMO_EVENTS: list[dict] = [
    {"title": "Jazz Night — Nardis Jazz Club", "category": "music", "subcategory": "jazz",
     "venue_name": "Nardis Jazz Club", "address": "Kuledibi Sok. No:14, Beyoğlu",
     "city": "Istanbul", "is_ticketed": True, "price_min": 250, "price_max": 400,
     "tags": ["jazz", "live music", "Beyoğlu"], "popularity_score": 0.82},
    {"title": "Babylon Live Music Night", "category": "music", "subcategory": "concert",
     "venue_name": "Babylon", "address": "Şehbender Sok. No:3, Asmalımescit",
     "city": "Istanbul", "is_ticketed": True, "price_min": 200, "price_max": 350,
     "tags": ["live music", "Beyoğlu", "nightlife"], "popularity_score": 0.79},
    {"title": "Istanbul Modern — Contemporary Art Exhibition", "category": "culture", "subcategory": "museum",
     "venue_name": "İstanbul Modern", "address": "Meclis-i Mebusan Cad., Karaköy",
     "city": "Istanbul", "is_ticketed": True, "price_min": 100, "price_max": 200,
     "tags": ["contemporary art", "museum", "Karaköy"], "popularity_score": 0.91},
    {"title": "Pera Museum — Orientalist Painting Collection", "category": "culture", "subcategory": "museum",
     "venue_name": "Pera Müzesi", "address": "Meşrutiyet Cad. No:65, Tepebaşı",
     "city": "Istanbul", "is_ticketed": True, "price_min": 75, "price_max": 150,
     "tags": ["museum", "art", "Beyoğlu"], "popularity_score": 0.88},
    {"title": "Bosphorus Sunset Boat Tour", "category": "outdoor", "subcategory": "boat",
     "venue_name": "Beşiktaş İskelesi", "address": "Beşiktaş Meydanı",
     "city": "Istanbul", "is_ticketed": True, "price_min": 200, "price_max": 350,
     "tags": ["boat", "Bosphorus", "sunset"], "popularity_score": 0.89},
    {"title": "Kadıköy Food Tour", "category": "food", "subcategory": "food-tasting",
     "venue_name": "Kadıköy Çarşısı", "address": "Mühürdar Cad., Kadıköy",
     "city": "Istanbul", "is_ticketed": True, "price_min": 300, "price_max": 300,
     "tags": ["food", "tour", "Kadıköy"], "popularity_score": 0.83},
    {"title": "Maçka Park Outdoor Yoga", "category": "outdoor", "subcategory": "open-air",
     "venue_name": "Maçka Demokrasi Parkı", "address": "Maçka, Beşiktaş",
     "city": "Istanbul", "is_ticketed": False, "price_min": 0, "price_max": 0,
     "tags": ["yoga", "morning", "park", "free"], "popularity_score": 0.72},
    {"title": "Ceramics Workshop — Cihangir", "category": "workshop", "subcategory": "workshop",
     "venue_name": "Cihangir Sanat Atölyesi", "address": "Akarsu Cad., Cihangir",
     "city": "Istanbul", "is_ticketed": True, "price_min": 400, "price_max": 600,
     "tags": ["ceramics", "workshop", "crafts"], "popularity_score": 0.71},
    {"title": "Istanbul Marathon Training Run", "category": "sports", "subcategory": "marathon-run",
     "venue_name": "Fenerbahçe Parkı", "address": "Bağdat Cad., Kadıköy",
     "city": "Istanbul", "is_ticketed": False, "price_min": 0, "price_max": 0,
     "tags": ["running", "marathon", "group", "free"], "popularity_score": 0.69},
    {"title": "Topkapi Palace Guided Tour", "category": "culture", "subcategory": "exhibition",
     "venue_name": "Topkapı Sarayı", "address": "Sultanahmet, Fatih",
     "city": "Istanbul", "is_ticketed": True, "price_min": 150, "price_max": 400,
     "tags": ["historic", "museum", "Ottoman"], "popularity_score": 0.93},
    # Kocaeli
    {"title": "Sapanca Lake Nature Walk", "category": "outdoor", "subcategory": "open-air",
     "venue_name": "Sapanca Gölü", "address": "Sapanca, Kocaeli",
     "city": "Kocaeli", "is_ticketed": False, "price_min": 0, "price_max": 0,
     "tags": ["lake", "nature", "hiking", "free"], "popularity_score": 0.91},
    {"title": "Jazz Night — Kocaeli Cultural Centre", "category": "music", "subcategory": "jazz",
     "venue_name": "Kocaeli Kültür Merkezi", "address": "İzmit Meydan, İzmit",
     "city": "Kocaeli", "is_ticketed": True, "price_min": 100, "price_max": 200,
     "tags": ["jazz", "live music", "İzmit"], "popularity_score": 0.71},
]


def ensure_demo_events() -> None:
    """Insert hard-coded demo events if the events table is nearly empty."""
    try:
        with httpx.Client(timeout=8) as client:
            resp = client.get(
                f"{SUPABASE_URL}/rest/v1/events",
                headers=_SUPA_HEADERS,
                params={"source": "eq.curated", "select": "id", "limit": "5"},
            )
        if resp.status_code == 200 and len(resp.json() or []) >= 5:
            logger.info("[seed] curated events already present, skipping demo seed")
            return
    except Exception as e:
        logger.warning("[seed] check failed: %s", e)
        return

    now = datetime.now(timezone.utc)
    rows = []
    for ev in _DEMO_EVENTS:
        title, city = ev["title"], ev["city"]
        rows.append({
            "source":          "curated",
            "external_id":     _make_external_id(title, city, None),
            "title":           title,
            "description":     None,
            "category":        ev["category"],
            "subcategory":     ev.get("subcategory"),
            "venue_name":      ev.get("venue_name"),
            "address":         ev.get("address"),
            "city":            city,
            "is_recurring":    True,
            "is_ticketed":     ev.get("is_ticketed", False),
            "price_min":       ev.get("price_min"),
            "price_max":       ev.get("price_max"),
            "currency":        "TRY",
            "tags":            ev.get("tags", []),
            "language":        "en",
            "popularity_score": ev.get("popularity_score", 0.5),
            "expires_at":      None,
            "updated_at":      now.isoformat(),
        })

    try:
        headers = {**_SUPA_HEADERS, "Prefer": "resolution=merge-duplicates,return=minimal"}
        with httpx.Client(timeout=15) as client:
            resp = client.post(
                f"{SUPABASE_URL}/rest/v1/events",
                params={"on_conflict": "external_id"},
                headers=headers,
                json=rows,
            )
        if resp.status_code in (200, 201):
            logger.info("[seed] inserted %d demo events", len(rows))
        else:
            logger.warning("[seed] failed status=%s body=%s", resp.status_code, resp.text[:200])
    except Exception as e:
        logger.warning("[seed] insert failed: %s", e)


if __name__ == "__main__":
    import sys
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s | %(message)s")
    cities = sys.argv[1:] if len(sys.argv) > 1 else SCRAPER_CITIES
    for city in cities:
        evs = scrape_city(city)
        print(f"\n{city}: {len(evs)} events")
        for e in evs:
            print(
                f"  [{e['title']}] "
                f"cat={e.get('category')} sub={e.get('subcategory')} "
                f"venue={e.get('venue_name')} "
                f"starts={e.get('starts_at')} ends={e.get('ends_at')} "
                f"ticket={e.get('ticket_url')} "
                f"tags={e.get('tags')} "
                f"lat={e.get('lat')}"
            )
        upsert_events(evs)
