"""
Simulation Configuration & Constants
Centralized settings for the persona-conditioned smartphone telemetry simulation.

Sections:
  1. Simulation parameters
  2. Geography / Istanbul region
  3. POI categories
  4. Internal-state dynamics (energy, hunger, boredom, social_need)
  5. Mobility / GPS noise
  6. Application catalog (categories, session durations, engagement)
  7. Output configuration
"""

import math
import os

# ============================================================================
# 1. SIMULATION PARAMETERS
# ============================================================================

TICK_DURATION_MINUTES = 5            # Each simulation step = 5 minutes
SIMULATION_DAYS = 7                  # Default run length
NUM_AGENTS = 100                     # Default population size
RANDOM_SEED = 42

TICKS_PER_HOUR = 60 // TICK_DURATION_MINUTES   # 12
TICKS_PER_DAY = 24 * TICKS_PER_HOUR             # 288
TOTAL_TICKS = SIMULATION_DAYS * TICKS_PER_DAY

# ============================================================================
# 2. GEOGRAPHY (Istanbul reference frame)
# ============================================================================

REGION = "istanbul"
LAT_CENTER = 41.0082
LON_CENTER = 28.9784

LAT_MIN = LAT_CENTER - 0.10
LAT_MAX = LAT_CENTER + 0.10
LON_MIN = LON_CENTER - 0.15
LON_MAX = LON_CENTER + 0.15

EARTH_RADIUS_M = 6371000
M_PER_DEGREE_LAT = 111000
M_PER_DEGREE_LON_AT_ISTANBUL = 111000 * math.cos(math.radians(LAT_CENTER))

# ============================================================================
# 3. POI CATEGORIES (used by osm_integration)
# ============================================================================

POI_CATEGORIES = {
    "HOME":       {"weight": 0.30, "count_target": 200, "osm_tags": ["building=residential"]},
    "WORK":       {"weight": 0.20, "count_target": 80,  "osm_tags": ["office", "amenity=office", "building=commercial"]},
    "SCHOOL":     {"weight": 0.05, "count_target": 30,  "osm_tags": ["amenity=university", "amenity=school", "amenity=college"]},
    "CAFE":       {"weight": 0.15, "count_target": 100, "osm_tags": ["amenity=cafe", "amenity=restaurant", "amenity=fast_food"]},
    "PARK":       {"weight": 0.05, "count_target": 40,  "osm_tags": ["leisure=park", "leisure=playground"]},
    "SHOPPING":   {"weight": 0.08, "count_target": 50,  "osm_tags": ["shop=supermarket", "shop=mall", "amenity=marketplace"]},
    "GYM":        {"weight": 0.04, "count_target": 25,  "osm_tags": ["leisure=fitness_centre", "amenity=gym"]},
    "NIGHTLIFE":  {"weight": 0.05, "count_target": 30,  "osm_tags": ["amenity=bar", "amenity=pub", "amenity=nightclub"]},
    "TRANSIT":    {"weight": 0.04, "count_target": 25,  "osm_tags": ["public_transport=station", "railway=station"]},
    "LANDMARK":   {"weight": 0.04, "count_target": 25,  "osm_tags": ["tourism=attraction", "historic=monument"]},
}

# ============================================================================
# 4. INTERNAL STATE DYNAMICS
# ============================================================================

STATE_MIN = 0.0
STATE_MAX = 100.0

# Energy
ENERGY_DECAY_ACTIVE = 1.5
ENERGY_DECAY_IDLE = 0.2
ENERGY_RECOVERY_SLEEP = 10.0
ENERGY_RECOVERY_REST = 2.0
ENERGY_THRESHOLD_SLEEP = 25.0

# Boredom
BOREDOM_INCREMENT_IDLE = 2.0
BOREDOM_INCREMENT_WORK = 0.5
BOREDOM_DECAY_LEISURE = 2.0
BOREDOM_DECAY_SOCIAL = 3.0
BOREDOM_THRESHOLD_SEEK_ACTIVITY = 60.0

# Social need
SOCIAL_NEED_INCREMENT = 0.6
SOCIAL_NEED_DECAY_SOCIAL = 5.0
SOCIAL_NEED_DECAY_FAMILY = 1.5

# Hunger
HUNGER_INCREMENT = 0.4
HUNGER_THRESHOLD_EAT = 65.0
HUNGER_RECOVERY_EAT = 30.0

# ============================================================================
# 5. MOBILITY & GPS
# ============================================================================

WALKING_SPEED_M_PER_MIN = 84.0          # ~5 km/h
CYCLING_SPEED_M_PER_MIN = 240.0         # ~14 km/h
DRIVING_SPEED_M_PER_MIN = 500.0         # ~30 km/h
TRANSIT_SPEED_M_PER_MIN = 360.0         # ~22 km/h

GPS_NOISE_STD_M_STATIONARY = 5.0
GPS_NOISE_STD_M_MOVING = 12.0
GPS_SAMPLING_INTERVAL_MINUTES = 10      # Ping every 10 minutes

# ============================================================================
# 6. APPLICATION CATALOG
# ============================================================================
#
# Categories used by personas/episodes:
#   social, messaging, video, short_video, music, gaming, streaming,
#   productivity, browser, navigation, fitness, education, news,
#   reading, finance, shopping, dating, photo, ride_share
#
# avg_session_min  — (min, max) for sampling session durations
# engagement       — 0..1 used for dopamine-loop weighting

APPS = {
    # --- social / messaging ----------------------------------------------
    "instagram":    {"category": "social",       "avg_session_min": (8, 60),   "engagement": 0.85, "battery_drain_per_min": 0.4},
    "tiktok":       {"category": "short_video",  "avg_session_min": (15, 180), "engagement": 0.95, "battery_drain_per_min": 0.8},
    "twitter":      {"category": "social",       "avg_session_min": (5, 45),   "engagement": 0.75, "battery_drain_per_min": 0.3},
    "snapchat":     {"category": "social",       "avg_session_min": (3, 30),   "engagement": 0.7,  "battery_drain_per_min": 0.4},
    "reddit":       {"category": "social",       "avg_session_min": (10, 90),  "engagement": 0.8,  "battery_drain_per_min": 0.3},
    "facebook":     {"category": "social",       "avg_session_min": (5, 30),   "engagement": 0.5,  "battery_drain_per_min": 0.3},
    "whatsapp":     {"category": "messaging",    "avg_session_min": (1, 25),   "engagement": 0.6,  "battery_drain_per_min": 0.1},
    "telegram":     {"category": "messaging",    "avg_session_min": (1, 30),   "engagement": 0.6,  "battery_drain_per_min": 0.1},
    "discord":      {"category": "messaging",    "avg_session_min": (15, 240), "engagement": 0.85, "battery_drain_per_min": 0.3},

    # --- video / streaming ------------------------------------------------
    "youtube":      {"category": "video",        "avg_session_min": (10, 120), "engagement": 0.85, "battery_drain_per_min": 0.7},
    "netflix":      {"category": "streaming",    "avg_session_min": (30, 180), "engagement": 0.8,  "battery_drain_per_min": 0.7},
    "twitch":       {"category": "streaming",    "avg_session_min": (30, 240), "engagement": 0.9,  "battery_drain_per_min": 0.8},
    "disney_plus":  {"category": "streaming",    "avg_session_min": (30, 150), "engagement": 0.75, "battery_drain_per_min": 0.7},

    # --- music / podcast --------------------------------------------------
    "spotify":      {"category": "music",        "avg_session_min": (15, 90),  "engagement": 0.5,  "battery_drain_per_min": 0.2},
    "apple_music":  {"category": "music",        "avg_session_min": (15, 90),  "engagement": 0.5,  "battery_drain_per_min": 0.2},
    "podcasts":     {"category": "music",        "avg_session_min": (20, 120), "engagement": 0.5,  "battery_drain_per_min": 0.2},

    # --- gaming -----------------------------------------------------------
    "mobile_legends": {"category": "gaming",     "avg_session_min": (20, 120), "engagement": 0.95, "battery_drain_per_min": 1.2},
    "pubg_mobile":    {"category": "gaming",     "avg_session_min": (25, 150), "engagement": 0.95, "battery_drain_per_min": 1.3},
    "clash_royale":   {"category": "gaming",     "avg_session_min": (5, 30),   "engagement": 0.8,  "battery_drain_per_min": 0.9},
    "candy_crush":    {"category": "gaming",     "avg_session_min": (5, 25),   "engagement": 0.6,  "battery_drain_per_min": 0.6},
    "valorant_mobile":{"category": "gaming",     "avg_session_min": (30, 180), "engagement": 0.95, "battery_drain_per_min": 1.3},

    # --- productivity / browser ------------------------------------------
    "gmail":        {"category": "productivity", "avg_session_min": (3, 25),   "engagement": 0.4,  "battery_drain_per_min": 0.2},
    "outlook":      {"category": "productivity", "avg_session_min": (3, 25),   "engagement": 0.4,  "battery_drain_per_min": 0.2},
    "teams":        {"category": "productivity", "avg_session_min": (10, 60),  "engagement": 0.5,  "battery_drain_per_min": 0.3},
    "slack":        {"category": "productivity", "avg_session_min": (5, 40),   "engagement": 0.5,  "battery_drain_per_min": 0.2},
    "notion":       {"category": "productivity", "avg_session_min": (10, 60),  "engagement": 0.5,  "battery_drain_per_min": 0.2},
    "chrome":       {"category": "browser",      "avg_session_min": (5, 60),   "engagement": 0.5,  "battery_drain_per_min": 0.3},

    # --- navigation / ride share -----------------------------------------
    "maps":         {"category": "navigation",   "avg_session_min": (5, 40),   "engagement": 0.7,  "battery_drain_per_min": 0.5},
    "yandex_maps":  {"category": "navigation",   "avg_session_min": (5, 40),   "engagement": 0.7,  "battery_drain_per_min": 0.5},
    "uber":         {"category": "ride_share",   "avg_session_min": (3, 15),   "engagement": 0.6,  "battery_drain_per_min": 0.3},
    "bitaksi":      {"category": "ride_share",   "avg_session_min": (3, 15),   "engagement": 0.6,  "battery_drain_per_min": 0.3},

    # --- fitness ----------------------------------------------------------
    "strava":       {"category": "fitness",      "avg_session_min": (30, 120), "engagement": 0.7,  "battery_drain_per_min": 0.6},
    "nike_run":     {"category": "fitness",      "avg_session_min": (30, 90),  "engagement": 0.7,  "battery_drain_per_min": 0.6},
    "fitbit":       {"category": "fitness",      "avg_session_min": (5, 30),   "engagement": 0.5,  "battery_drain_per_min": 0.2},

    # --- education --------------------------------------------------------
    "duolingo":     {"category": "education",    "avg_session_min": (5, 30),   "engagement": 0.6,  "battery_drain_per_min": 0.2},
    "coursera":     {"category": "education",    "avg_session_min": (20, 120), "engagement": 0.5,  "battery_drain_per_min": 0.4},
    "khan_academy": {"category": "education",    "avg_session_min": (20, 90),  "engagement": 0.5,  "battery_drain_per_min": 0.3},

    # --- reading / news ---------------------------------------------------
    "kindle":       {"category": "reading",      "avg_session_min": (15, 90),  "engagement": 0.5,  "battery_drain_per_min": 0.2},
    "medium":       {"category": "reading",      "avg_session_min": (10, 40),  "engagement": 0.5,  "battery_drain_per_min": 0.2},
    "news":         {"category": "news",         "avg_session_min": (5, 30),   "engagement": 0.5,  "battery_drain_per_min": 0.2},

    # --- finance / commerce ----------------------------------------------
    "banking":      {"category": "finance",      "avg_session_min": (2, 10),   "engagement": 0.4,  "battery_drain_per_min": 0.1},
    "trendyol":     {"category": "shopping",     "avg_session_min": (5, 40),   "engagement": 0.6,  "battery_drain_per_min": 0.3},
    "getir":        {"category": "shopping",     "avg_session_min": (3, 15),   "engagement": 0.5,  "battery_drain_per_min": 0.3},

    # --- dating / photo ---------------------------------------------------
    "tinder":       {"category": "dating",       "avg_session_min": (5, 40),   "engagement": 0.7,  "battery_drain_per_min": 0.3},
    "camera":       {"category": "photo",        "avg_session_min": (1, 8),    "engagement": 0.5,  "battery_drain_per_min": 0.5},
    "gallery":      {"category": "photo",        "avg_session_min": (2, 10),   "engagement": 0.4,  "battery_drain_per_min": 0.2},
}

# Useful category groupings for episodes ------------------------------------

CATEGORY_GROUPS = {
    "social_messaging":   ["social", "messaging"],
    "passive_media":      ["video", "short_video", "streaming"],
    "active_listen":      ["music"],
    "gaming":             ["gaming"],
    "navigation":         ["navigation", "ride_share"],
    "productivity":       ["productivity", "browser"],
    "education":          ["education"],
    "fitness":            ["fitness"],
    "reading_news":       ["reading", "news"],
    "commerce":           ["shopping", "finance"],
    "photo":              ["photo"],
}


def apps_in_categories(*categories) -> list:
    """Return all app names whose category is in the given list."""
    flat = []
    for c in categories:
        if c in CATEGORY_GROUPS:
            flat.extend(CATEGORY_GROUPS[c])
        else:
            flat.append(c)
    return [name for name, meta in APPS.items() if meta["category"] in flat]


# ============================================================================
# 7. OUTPUT CONFIGURATION
# ============================================================================

OUTPUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "outputs", "sim_out")
)

# ============================================================================
# 8. API CONFIG (Overpass)
# ============================================================================

OVERPASS_API_URL = "https://overpass-api.de/api/interpreter"
OVERPASS_TIMEOUT_SEC = 30
API_REQUEST_DELAY_SEC = 0.5
