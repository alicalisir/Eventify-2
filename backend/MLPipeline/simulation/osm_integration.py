"""
OpenStreetMap Integration
Query real POIs from Overpass API
"""

import requests
import time
import logging
from typing import Dict, List
import config
import utils

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def query_overpass_api(
    lat_min: float,
    lat_max: float,
    lon_min: float,
    lon_max: float,
    poi_category: str,
    osm_tags: List[str],
) -> List[Dict]:
    """
    Query Overpass API for POIs matching given tags.

    Args:
        lat_min, lat_max, lon_min, lon_max: Bounding box
        poi_category: Category name (HOME, WORK, etc.)
        osm_tags: List of OSM tags to search for

    Returns:
        List of POI dicts: {id, name, lat, lon, type, tags}
    """
    # Build Overpass query
    # Format: [bbox]; (node[tag=value];way[tag=value];);out geom;
    tags_or = " OR ".join([f'"{tag}"' for tag in osm_tags])

    query = f"""
    [bbox:{lat_min},{lon_min},{lat_max},{lon_max}];
    (
        node[{tags_or}];
        way[{tags_or}];
        relation[{tags_or}];
    );
    out geom;
    """

    logger.info(f"Querying Overpass API for {poi_category} POIs...")

    try:
        response = requests.post(
            config.OVERPASS_API_URL,
            data=query,
            timeout=config.OVERPASS_TIMEOUT_SEC,
        )
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        logger.error(f"Overpass API error: {e}")
        return []

    # Parse response
    data = response.json()
    pois = []

    for element in data.get("elements", []):
        poi = _parse_osm_element(element, poi_category)
        if poi:
            pois.append(poi)

    logger.info(f"  Found {len(pois)} {poi_category} POIs")
    return pois


def _parse_osm_element(element: Dict, category: str) -> Dict:
    """
    Parse OSM element (node/way/relation) into POI dict.
    """
    tags = element.get("tags", {})
    name = tags.get("name", f"Unnamed {category} #{element.get('id')}")

    # Extract coordinates
    if element["type"] == "node":
        lat = element.get("lat")
        lon = element.get("lon")
    elif element["type"] == "way":
        # Use centroid of way
        geometry = element.get("geometry", [])
        if geometry:
            lats = [g["lat"] for g in geometry]
            lons = [g["lon"] for g in geometry]
            lat = sum(lats) / len(lats)
            lon = sum(lons) / len(lons)
        else:
            return None
    else:  # relation
        # Use center from members or skip
        return None

    if lat is None or lon is None:
        return None

    return {
        "id": element.get("id"),
        "name": name,
        "latitude": lat,
        "longitude": lon,
        "type": category,
        "osm_type": element["type"],
        "address": tags.get("addr:full", tags.get("addr:street", "Unknown")),
    }


def fetch_real_environment(region: str = "istanbul") -> Dict[str, List[Dict]]:
    """
    Fetch all POIs for a region from OpenStreetMap.

    Returns:
        {category: [POI list]}
        Example:
        {
            "HOME": [
                {"id": 123, "name": "Residential Area", "latitude": 41.0, "longitude": 28.9, ...},
                ...
            ],
            "WORK": [...],
            ...
        }
    """
    pois_by_category = {}

    for category, settings in config.POI_CATEGORIES.items():
        osm_tags = settings["osm_tags"]

        # Query Overpass API
        pois = query_overpass_api(
            config.LAT_MIN,
            config.LAT_MAX,
            config.LON_MIN,
            config.LON_MAX,
            category,
            osm_tags,
        )

        # Limit to target count
        target = settings["count_target"]
        if len(pois) > target:
            pois = pois[:target]

        pois_by_category[category] = pois

        # Rate limiting
        time.sleep(config.API_REQUEST_DELAY_SEC)

    logger.info(f"Total POIs fetched: {sum(len(p) for p in pois_by_category.values())}")
    return pois_by_category


def get_cached_environment() -> Dict[str, List[Dict]]:
    """
    Return a procedurally-generated environment (fallback if API fails).
    Creates realistic POI distribution without hitting API.
    """
    logger.warning("Using procedurally-generated environment (no API)")

    pois_by_category = {}

    for category, settings in config.POI_CATEGORIES.items():
        target = settings["count_target"]
        pois = []

        for i in range(target):
            lat, lon = utils.generate_random_location_in_bounds()
            pois.append(
                {
                    "id": f"{category}_{i}",
                    "name": f"{category} #{i+1}",
                    "latitude": lat,
                    "longitude": lon,
                    "type": category,
                    "osm_type": "node",
                    "address": "Generated Location",
                }
            )

        pois_by_category[category] = pois

    logger.info(
        f"Generated {sum(len(p) for p in pois_by_category.values())} synthetic POIs"
    )
    return pois_by_category


def load_environment(use_api: bool = True) -> Dict[str, List[Dict]]:
    """
    Load environment from API or fallback to procedural generation.

    Args:
        use_api: Try to fetch from Overpass API

    Returns:
        POIs by category
    """
    if use_api:
        try:
            return fetch_real_environment()
        except Exception as e:
            logger.error(f"Failed to fetch from API: {e}")
            logger.info("Falling back to procedural generation")
            return get_cached_environment()
    else:
        return get_cached_environment()
