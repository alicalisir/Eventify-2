export interface RecommendRequest {
  lat: number;
  lng: number;
  city: string;
  weather_condition: string; // clear|rain|snow|clouds
  weather_temp_c: number;
  hour: number; // 0-23
  day_of_week: number; // 0=Mon, 6=Sun
  motion_state: string; // stationary|walking|driving
  user_interests: string[];
  recent_dismissed_titles: string[];
  recent_liked_categories: string[];
}

export interface PersonaJson {
  persona_id: string;
  segment_label: string;
  traits: Array<{ label: string; confidence: number }>;
  preferences: Record<string, number>;
  model_version: string;
  inferred_at: string;
}

export interface NearbyEvent {
  event_id: string;
  title: string;
  category: string;
  venue_name: string | null;
  address: string | null;
  distance_m: number;
  starts_at: string | null;
  is_ticketed: boolean;
  price_min: number | null;
  price_max: number | null;
  currency: string;
}

export interface Suggestion {
  id: string;
  title: string;
  category: string;
  rationale: string;
  rationale_signals: string[];
  match_score: number;
  distance_m?: number;
  venue_name?: string;
  event_id?: string;
  ticket_url?: string;
}

export interface RecommendResponse {
  suggestions: Suggestion[];
  llm_provider: string;
  cache_hit: boolean;
  latency_ms: number;
}
