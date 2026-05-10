# Quick Start Guide - Agent-Based Smartphone Telemetry Simulation

## 30-Second Setup

```bash
# 1. Install dependencies (one-time)
pip install mesa pandas numpy requests scipy

# 2. Run simulation (generates 7 days of realistic telemetry)
cd c:\Users\alief\Desktop\FakeData
python simulation/simulate.py

# 3. Check output
ls out/
# → gps_pings.csv (100K+ records)
# → app_sessions.csv (86K+ records)
# → screen_events.csv (25K+ records)
# → users.csv (50 user profiles)
# → daily_summary.csv (350 daily stats)
```

---

## Key Files

| File | Purpose | Edit To |
|------|---------|---------|
| `simulation/config.py` | Settings & constants | Change NUM_AGENTS, SIMULATION_DAYS, region |
| `simulation/agent.py` | Agent personalities | Add/modify personas |
| `simulation/behavior.py` | Decision-making | Adjust utility weights |
| `simulation/simulate.py` | Run simulation | Adjust logging level |

---

## Common Customizations

### Run 3 Days with 100 Agents

Edit `simulation/config.py`:
```python
NUM_AGENTS = 100
SIMULATION_DAYS = 3
```

Then:
```bash
python simulation/simulate.py
```

### Change Region to Another City

```python
# In config.py:
LAT_CENTER = 40.7128  # New York
LON_CENTER = -74.0060
LAT_MIN = LAT_CENTER - 0.1
LAT_MAX = LAT_CENTER + 0.1
LON_MIN = LON_CENTER - 0.15
LON_MAX = LON_CENTER + 0.15
```

### Add a New App

```python
# In config.py APPS dict:
"snapchat": {
    "category": "social",
    "battery_drain_per_min": 0.5,
    "engagement_level": 0.8,
    "primary_actions": ["relax_at_home", "socialize"],
    "avg_session_min": (5, 30),
},

# Then in agent.py _get_app_for_action():
app_mapping["socialize"] = random.choice(["whatsapp", "snapchat"])
```

### Adjust Agent Behavior

```python
# In behavior.py calculate_action_utility():
# Make sleeping less attractive:
if action == "sleep":
    utility += -50  # was +50

# Make work more attractive:
if action == "work":
    utility += 100  # was +50
```

---

## Analyzing Output

### Python Quickstart

```python
import pandas as pd

# Load data
gps = pd.read_csv('out/gps_pings.csv')
apps = pd.read_csv('out/app_sessions.csv')
users = pd.read_csv('out/users.csv')

# User statistics
print(f"Total users: {users.shape[0]}")
print(f"Total GPS pings: {gps.shape[0]}")
print(f"Total app sessions: {apps.shape[0]}")

# GPS coverage per user
print("\nGPS pings per user:")
print(gps.groupby('user_id').size().describe())

# Top apps by duration
print("\nTop 10 apps by total duration:")
top_apps = apps.groupby('app')['duration_min'].sum().nlargest(10)
print(top_apps)

# User persona distribution
print("\nUser personas:")
print(users['persona'].value_counts())

# Sample user trajectory
user_0_gps = gps[gps['user_id'] == 0].head(100)
print(f"\nUser 0 coordinates (first 100 samples):")
print(user_0_gps[['latitude', 'longitude']])
```

### Excel/Google Sheets

1. Open `out/gps_pings.csv` in Excel
2. Select lat/lon columns → Insert → Chart → Scatter
3. Visualize user movement patterns

---

## Troubleshooting

### "ModuleNotFoundError: No module named 'mesa'"

```bash
pip install mesa
# If still issues:
pip install --upgrade mesa pandas numpy
```

### Slow Simulation

- Reduce `NUM_AGENTS` in config.py
- Reduce `SIMULATION_DAYS`
- Test on Phase 1: 1 day, 5 agents

### Memory Issues

- Run with fewer agents (50 → 25)
- Shorter duration (7 → 3 days)
- Each agent ≈ 10MB for 7 days

### No Output Files

- Check `out/` directory exists (creates automatically)
- Run: `python -c "import pandas; print('OK')"` to verify pandas installed
- Check console for errors before "Export complete!"

---

## What's Being Generated?

Each agent simulates **7 days of realistic behavior**:

```
Monday 9 AM
├─ Wake up (energy from sleep)
├─ Commute to work (GPS → Maps app)
├─ Work 9-5 (GPS at office, Gmail/Teams)
├─ Lunch at cafe (Maps navigation, Spotify)
├─ Back to work
├─ Commute home (Maps)
├─ Relax at home (TikTok/Instagram)
└─ Sleep (screen off)

× 7 days × 50 agents = 100,800 GPS pings generated
```

---

## Integration with Existing FakeData Pipeline

Output directly compatible with:
- `gps_to_places.py` - Convert GPS to semantic locations
- `user_profiling.py` - Feature extraction
- `semantic_profiler.py` - Behavioral categorization
- `ai_processor.py` - LLM-based persona assignment

### Full Pipeline

```bash
# 1. Generate data
python simulation/simulate.py

# 2. Convert GPS to places
python gps_to_places.py

# 3. Extract features
python user_profiling.py

# 4. Semantic analysis
python semantic_profiler.py

# 5. AI-powered insights
python ai_processor.py
```

---

## Understanding Agent Behavior

### Utility-Based Decision System

Agent evaluates 9 actions every 5 minutes:

```
Action Utilities:
  work:             85  ← High energy, work hours, work-focused
  relax_at_home:    45
  go_to_cafe:       30
  sleep:            15
  exercise:         20
  ...

→ Softmax selection: 85% probability of "work"
```

### Internal States Drive Behavior

```
9:00 AM - Office Worker Agent
  Energy:        85/100 (well-rested)
  Boredom:       5/100 (fresh)
  Social Need:   10/100 (introverted)
  
  → Action: "work"
  → App: "gmail"
  → GPS: Office location
  → Screen: ON

5:00 PM - After Work
  Energy:        40/100 (tired)
  Boredom:       75/100 (worked all day)
  Social Need:   60/100 (want to relax)
  
  → Action: "relax_at_home"
  → App: "tiktok"
  → Screen: ON for 60 minutes
```

---

## Next Steps

1. **Run the simulation** ← Start here
2. **Explore the output files**
3. **Customize personas/behavior**
4. **Integrate with your analysis pipeline**
5. **Validate against real datasets**

---

## Performance Targets

| Metric | Value |
|--------|-------|
| Agents | 50 |
| Duration | 7 days |
| GPS pings | 100,800 |
| App sessions | 86,654 |
| Runtime | 30-45 sec |
| Output size | ~20 MB |

---

## Support

See `README.md` for detailed documentation of all modules, configuration options, and advanced usage.

Questions? Check the code comments—they're comprehensive!
