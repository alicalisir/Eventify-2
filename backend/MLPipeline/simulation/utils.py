"""
Utility functions for simulation
Helpers for distance, time, GPS noise, etc.
"""

import math
import numpy as np
from datetime import datetime, timedelta
from typing import Tuple
import config


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate great-circle distance between two points on Earth (meters).

    Args:
        lat1, lon1: First point (degrees)
        lat2, lon2: Second point (degrees)

    Returns:
        Distance in meters
    """
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return config.EARTH_RADIUS_M * c


def add_gps_noise(
    lat: float,
    lon: float,
    noise_std_m: float = config.GPS_NOISE_STD_M_STATIONARY
) -> Tuple[float, float]:
    """
    Add realistic Gaussian GPS noise to coordinates.

    Args:
        lat, lon: Original coordinates
        noise_std_m: Standard deviation of noise in meters

    Returns:
        (noisy_lat, noisy_lon)
    """
    # Convert meters to degrees (~111km per degree latitude)
    lat_noise_deg = np.random.normal(0, noise_std_m / config.M_PER_DEGREE_LAT)
    lon_noise_deg = np.random.normal(0, noise_std_m / config.M_PER_DEGREE_LON_AT_ISTANBUL)

    return lat + lat_noise_deg, lon + lon_noise_deg


def interpolate_path(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
    distance_m: float,
    speed_m_per_min: float = config.WALKING_SPEED_M_PER_MIN,
) -> list:
    """
    Generate intermediate waypoints along a path between two points.

    Args:
        lat1, lon1: Start point
        lat2, lon2: End point
        distance_m: Total distance (from haversine)
        speed_m_per_min: Movement speed

    Returns:
        List of (lat, lon) tuples for waypoints
    """
    travel_time_min = distance_m / speed_m_per_min
    num_waypoints = max(2, int(travel_time_min / config.TICK_DURATION_MINUTES))

    waypoints = []
    for i in range(num_waypoints):
        fraction = i / (num_waypoints - 1) if num_waypoints > 1 else 0
        lat = lat1 + (lat2 - lat1) * fraction
        lon = lon1 + (lon2 - lon1) * fraction
        waypoints.append((lat, lon))

    return waypoints


def tick_to_datetime(tick: int, start_datetime: datetime = None) -> datetime:
    """
    Convert simulation tick to actual datetime.

    Args:
        tick: Simulation step number
        start_datetime: Starting datetime (default: Jan 1, 2024, 00:00)

    Returns:
        datetime object
    """
    if start_datetime is None:
        start_datetime = datetime(2024, 1, 1, 0, 0, 0)

    elapsed_minutes = tick * config.TICK_DURATION_MINUTES
    return start_datetime + timedelta(minutes=elapsed_minutes)


def datetime_to_tick(dt: datetime, start_datetime: datetime = None) -> int:
    """
    Convert datetime to simulation tick.
    """
    if start_datetime is None:
        start_datetime = datetime(2024, 1, 1, 0, 0, 0)

    delta = dt - start_datetime
    return int(delta.total_seconds() / (config.TICK_DURATION_MINUTES * 60))


def get_time_of_day(hour: int) -> str:
    """
    Classify hour into time period.

    Returns: 'night', 'morning', 'work', 'evening'
    """
    if 0 <= hour < 7:
        return "night"
    elif 7 <= hour < 9:
        return "morning"
    elif 9 <= hour < 17:
        return "work"
    else:  # 17-24
        return "evening"


def is_weekend(date: datetime) -> bool:
    """Check if date is weekend (Saturday/Sunday)."""
    return date.weekday() >= 5  # 5=Saturday, 6=Sunday


def softmax(utilities: dict, temperature: float = 1.0) -> str:
    """
    Softmax selection: convert utility scores to probabilities.

    Args:
        utilities: Dict of {action: score}
        temperature: Higher = more random, lower = more deterministic

    Returns:
        Selected action name
    """
    # Normalize utilities
    actions = list(utilities.keys())
    scores = np.array(list(utilities.values()))

    # Handle all zeros
    if np.all(scores == 0):
        return np.random.choice(actions)

    # Softmax: exp(score/T) / sum(exp(...))
    exp_scores = np.exp(scores / temperature)
    probabilities = exp_scores / np.sum(exp_scores)

    return np.random.choice(actions, p=probabilities)


def clamp(value: float, min_val: float = 0.0, max_val: float = 100.0) -> float:
    """Clamp value between min and max."""
    return max(min_val, min(max_val, value))


def degree_to_meters(degrees: float, is_latitude: bool = True) -> float:
    """
    Convert degrees to approximate meters.

    Args:
        degrees: Degrees of latitude or longitude
        is_latitude: True for latitude, False for longitude

    Returns:
        Approximate distance in meters
    """
    if is_latitude:
        return degrees * config.M_PER_DEGREE_LAT
    else:
        return degrees * config.M_PER_DEGREE_LON_AT_ISTANBUL


def meters_to_degree(meters: float, is_latitude: bool = True) -> float:
    """Convert meters to approximate degrees."""
    if is_latitude:
        return meters / config.M_PER_DEGREE_LAT
    else:
        return meters / config.M_PER_DEGREE_LON_AT_ISTANBUL


def generate_random_location_in_bounds() -> Tuple[float, float]:
    """
    Generate random (lat, lon) within Istanbul bounds.
    """
    lat = np.random.uniform(config.LAT_MIN, config.LAT_MAX)
    lon = np.random.uniform(config.LON_MIN, config.LON_MAX)
    return lat, lon
