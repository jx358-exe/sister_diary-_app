# Sister Diary API

Flutter talks to this FastAPI service; only the service connects to MongoDB. Keep the MongoDB URI on the server and never put it in Flutter's `--dart-define` or source code.

## Start locally

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env: set the MongoDB URI and a long random AUTH_SECRET.
# Configure SMTP_* for email codes and TWILIO_* for SMS codes before enabling registration.
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Check `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/docs`.

Run Flutter with the API URL:

```bash
cd sisterdiary_new
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

For Android Emulator, use `http://10.0.2.2:8000`; for a physical phone, use the computer's LAN IP and allow that origin in `CORS_ORIGINS`.

The app now creates an isolated guest account automatically on first launch, so local and cloud features do not require email or SMS verification. Each installation keeps its own guest data. Guest sessions expire after 30 days and can be renewed with the same installation ID. Email/phone registration and password sign-in remain available for a later account flow; those registration channels require SMTP/Twilio configuration.

Retention: schedules, My Plan items, and date-linked diary/chat/health records expire after 60 days by default. The storage screen lets the user manually clean My Schedule-linked data or My Plan independently, using 15-, 30-, or 60-day age limits. Sharing Moment text expires after 5 days; garden state expires 30 days after its last update.

AI chat and daily health review use an OpenAI-compatible Chat Completions API. The backend accepts provider credentials only; never put an AI key in Flutter. For direct DeepSeek access, set `DEEPSEEK_API_KEY`, `DEEPSEEK_BASE_URL=https://api.deepseek.com`, and `DEEPSEEK_MODEL=deepseek-flash`. For OpenRouter, use `DEEPSEEK_BASE_URL=https://openrouter.ai/api/v1` and an OpenRouter model ID such as `openrouter/free`. The model provider and model ID must match. The base URL is the API root; the backend appends `/chat/completions`.

Chat history is saved with the selected date. Health analysis uses that date's My Schedule, diary, and chat data, then stores the analysis and practical advice in the same daily record. Free model routers may select a different model on each request and can have stricter rate limits or inconsistent structured output.

## Android app

Android release builds default to the deployed Render API (`https://sister-diary-api.onrender.com`). The server root URL can still be changed from the account screen or Settings. Enter the deployed backend's HTTPS URL, not the MongoDB URL or model provider URL. For an Android Emulator on the development computer, `http://10.0.2.2:8000` reaches a local backend. A physical phone needs a reachable HTTPS deployment or a computer LAN address. Keep API keys and MongoDB credentials on the backend.

Build an installable APK from the Flutter project root with `flutter build apk --release`. To override the default backend URL, pass `--dart-define=API_BASE_URL=https://your-api.example.com`. The APK is signed with the local debug certificate until a production signing key is configured.

SMTP and Twilio credentials are server-only environment variables. Set these on Render under the service's Environment page before enabling sign-up:

- Email: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, and `SMTP_FROM`.
- SMS (optional): `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM_NUMBER`.

Email or SMS registration returns a clear `503` until that channel is configured. Do not commit `.env`, publish real credentials, or put MongoDB or AI credentials in Flutter. Rotate any credential that has been exposed.
