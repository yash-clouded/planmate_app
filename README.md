# iternity

AI agent-powered group chat for planning trips, outings, dinners, and events.

## Features

- Phone number authentication with Firebase OTP
- Group chat with Stream Chat
- AI agent (`@agent`) that:
  - Summarizes trip planning conversations
  - Searches hotels, movies, and restaurants
  - Creates polls for group decisions
  - Generates payment links
- Trip mode with live map and location sharing
- SOS emergency alerts
- Responsive UI with keyboard-safe screens

## Tech Stack

**Frontend**
- Flutter (Dart)
- Stream Chat Flutter SDK
- Firebase Auth
- Provider state management
- Shared Preferences for local persistence

**Backend**
- FastAPI (Python)
- Redis for message history and rate limiting
- NVIDIA NIM for AI agent responses
- Stream Chat REST API for bot messaging

## Project Structure

```
planmate_app/
├── backend/
│   ├── app/
│   │   ├── config.py          # Environment settings
│   │   ├── main.py            # FastAPI entry point
│   │   ├── models/
│   │   ├── routers/
│   │   │   └── webhooks.py    # Stream webhooks + API endpoints
│   │   └── services/
│   │       ├── agent.py       # AI agent logic, tool calls
│   │       ├── redis_store.py # Redis message/state store
│   │       └── stream_service.py
│   ├── requirements.txt
│   └── render.yaml
└── lib/
    ├── main.dart
    ├── services/
    │   ├── api_config.dart    # Stream key + backend URL
    │   ├── auth_service.dart  # Firebase phone auth
    │   ├── backend_service.dart
    │   └── stream_service.dart
    ├── screens/
    └── widgets/
```

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.9.2)
- Python 3.10+
- Redis
- Firebase project with Phone Auth enabled
- Stream Chat account
- NVIDIA NIM API key

### Flutter Setup

1. Clone the repo
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Firebase:
   ```bash
   flutterfire configure
   ```
4. Update `lib/services/api_config.dart`:
   - Set `streamApiKey` from your Stream dashboard
   - Set `backendUrl` to your Render backend URL (e.g., `https://planmate-backend.onrender.com`)
5. Run the app:
   ```bash
   flutter run
   ```

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create a virtual environment and install dependencies:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```
3. Copy `.env.example` to `.env` and fill in your values:
   ```bash
   cp .env.example .env
   ```
4. Required environment variables:
   - `STREAM_API_KEY` — from Stream dashboard
   - `STREAM_API_SECRET` — from Stream dashboard
   - `NVIDIA_API_KEY` — from NVIDIA NIM
   - `WEBHOOK_SECRET` — optional, for webhook signature verification
   - `REDIS_URL` — Redis connection string
5. Run the server:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

### Backend Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/webhooks/stream` | Receive Stream Chat webhooks |
| POST | `/webhooks/confirm/{channel_id}` | Confirm booking |
| POST | `/webhooks/poll/vote` | Cast poll vote |
| POST | `/webhooks/sos` | Send SOS alert |
| POST | `/agent/command` | Direct agent commands |
| GET | `/health` | Health check |

## Deployment

### Backend on Render

1. Push the repo to GitHub
2. Create a new Blueprint on Render from the repo
3. Render will use `render.yaml` to create:
   - `planmate-backend` (web service)
   - `planmate-redis` (free Redis instance)
4. Set environment variables in Render dashboard:
   - `STREAM_API_KEY`
   - `STREAM_API_SECRET`
   - `NVIDIA_API_KEY`
   - `WEBHOOK_SECRET`
5. After deploy, update `lib/services/api_config.dart` with the Render URL

## Agent Commands

In any group chat, use these commands with `@agent` or directly:

| Command | Action |
|---------|--------|
| `@agent` or `@planmate` | General trip planning help |
| `poll` | Create a group poll |
| `poll Question \| Option1 \| Option2` | Create poll with custom options |
| `summarize` | Summarize recent conversation |
| `restaurants in <location>` | Search restaurants |
| `restaurants near <location>` | Search nearby restaurants |

## Environment Variables

**Backend (`.env` or Render env vars):**
```
STREAM_API_KEY=
STREAM_API_SECRET=
NVIDIA_API_KEY=
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_MODEL=deepseek-ai/deepseek-v4-flash-0731
REDIS_URL=redis://localhost:6379/0
WEBHOOK_SECRET=
```

**Flutter (`lib/services/api_config.dart`):**
```dart
static const String streamApiKey = 'YOUR_STREAM_API_KEY';
static const String backendUrl = 'https://your-backend-url.com';
```

## Roadmap

- Replace mock hotel/movie/restaurant APIs with real integrations
- Replace mock payment link with Razorpay/Stripe
- Add real image upload for group photos
- Add trip itinerary generation
- Add offline message sync
