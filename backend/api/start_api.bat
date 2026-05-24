@echo off
echo ==========================================
echo  Context-Aware Recommendation API
echo ==========================================

:: Install dependencies if needed
pip install -r requirements.txt --quiet

:: Show local IP for Flutter .env configuration
echo.
echo Your local IP addresses:
ipconfig | findstr /R "IPv4"
echo.
echo Use the WiFi IP above in:
echo   context_aware_event_recommendation_system\.env
echo   BACKEND_URL=http://YOUR_IP:8000
echo.
echo Starting API on http://0.0.0.0:8000 ...
echo Press Ctrl+C to stop.
echo.

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
